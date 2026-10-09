# Gemini searches on the pipeline host using its existing Google key. Only
# bounded learning context leaves Rails; the pipeline verifies search sources.
class DailyVideoRecommendation
  class InvalidRecommendation < StandardError; end

  def self.call(...) = new(...).call

  CONTENT_TYPES = %w[dialogue song story culture].freeze

  Result = Data.define(:url, :search_suggestions, :content_type, :video) do
    def initialize(url:, search_suggestions:, content_type: nil, video: nil)
      super
    end
  end

  def initialize(user:, language:, client: PipelineClient, preflight: Imports::VideoPreflight)
    @user, @language, @client = user, language, client
    @preflight = preflight
  end

  def call
    response = @client.recommend_video(context)
    url = canonical_video(response.fetch("url"))
    raise InvalidRecommendation, "No verified new video found" unless url && !excluded?(url)
    raise InvalidRecommendation, "Invalid content type" unless CONTENT_TYPES.include?(response["content_type"])
    video = @preflight.call(url).video
    if video.author_name.blank?
      raise InvalidRecommendation, "Video must have a channel"
    end
    Result.new(url: url, search_suggestions: response["search_suggestions"],
      content_type: response["content_type"], video: video)
  rescue KeyError, TypeError
    raise InvalidRecommendation, "Invalid search response"
  end

  private

  def canonical_video(url)
    uri = URI.parse(url.to_s)
    return unless uri.scheme == "https" && %w[youtube.com www.youtube.com m.youtube.com youtu.be].include?(uri.host)
    id = Youtube::Url.video_id(url)
    Youtube::Url.canonical(url) if id&.match?(Youtube::Url::BARE_ID)
  rescue URI::InvalidURIError
    nil
  end

  def context
    recent_imports = @user.import_requests.ready.where(clip_language: @language.english_name)
      .recent_first.limit(8)
    imports = recent_imports.pluck(:title, :youtube_url)
    words = @user.phrase_token_users.joins(phrase_token: :phrase)
      .where(phrases: { l1_id: @language.id }).order(created_at: :desc).limit(40)
      .includes(phrase_token: [ :phrase, :token_translations ])
    vocabulary = words.map { |entry| { word: entry.word.to_s.truncate(100), translation: entry.translation.to_s.truncate(100), sentence: entry.context.truncate(500) } }
    vocabulary_source = vocabulary.empty? ? "imported_transcript" : "saved_words"
    vocabulary = imported_vocabulary(recent_imports) if vocabulary.empty?
    { learning_language: recommendation_language,
      learning_language_code: @language.iso_name, learning_language_native_name: @language.native_name,
      vocabulary_source: vocabulary_source, completed_lessons: completed_lessons, variety_is_optional: true,
      imported_videos: imports.map { |title, url| { title: title.to_s.truncate(200), url: url } },
      vocabulary: vocabulary,
      previous_suggestions: previous_urls,
      preferred_content_type: preferred_content_type,
      excluded_channel: excluded_channel&.truncate(200),
      recent_recommendations: previous_videos.first(10).map { |video|
        { title: video["title"].to_s.truncate(200), content_type: video["content_type"],
          channel: video["channel"].to_s.truncate(200) }
      } }
  end

  # Keep import/pipeline language identifiers stable; make the recommendation's
  # dialect explicit instead of collapsing the Palestinian row to "Arabic".
  def recommendation_language
    @language.iso_name == "ar-JO" ? "Palestinian spoken Arabic (Levantine)" : @language.english_name
  end

  def completed_lessons
    @user.lesson_users.joins(lesson: :course).where(courses: { language_id: @language.id })
      .order(created_at: :desc).limit(8).includes(lesson: :course).map do |completion|
        lesson = completion.lesson
        sentences = Phrase.joins(activity_phrases: :activity)
          .where(activities: { lesson_id: lesson.id }, l1_id: @language.id)
          .select(:id, :text_l1).distinct.order(:id).limit(5).map(&:text_l1)
        { title: lesson.course.name.to_s.truncate(200), lesson_title: lesson.name.to_s.truncate(200),
          url: lesson.course.main_media_url.to_s.truncate(2048), sentences: sentences.map { |text| text.to_s.truncate(500) } }
      end
  end

  def imported_vocabulary(recent_imports)
    media = Lesson.where(course_id: recent_imports.select(:course_id)).select(:medium_id)
    # A bounded sample of transcript phrases, never another user's courses or
    # translated text. Gemini can use these source words to estimate the level.
    texts = Phrase.where(l1_id: @language.id, medium_id: media)
      .order(Arel.sql("RANDOM()")).limit(20).pluck(:text_l1)
    texts.flat_map { |text| text.to_s.split }.map { |word| word.gsub(/\A[^\p{L}\p{N}]+|[^\p{L}\p{N}]+\z/u, "") }
      .select { |word| word.match?(/\p{L}/u) }.uniq.sample(40)
      .map { |word| { word: word.truncate(100), translation: "" } }
  end

  def previous_urls
    previous_videos.filter_map { |video| video["url"] }
  end

  def previous_videos
    @previous_videos ||= DailyChallenge.where(starter_challenge_id: @user.starter_challenge&.id)
      .where("day > 5").where.not(recommended_video: {}).order(day: :desc).limit(30).pluck(:recommended_video)
  end

  def preferred_content_type
    previous_type = previous_videos.first&.fetch("content_type", nil)
    index = CONTENT_TYPES.index(previous_type)
    # Legacy suggestions have no category; still change the target each local day.
    day = @user.starter_challenge&.active_day || 6
    CONTENT_TYPES[index ? (index + 1) % CONTENT_TYPES.length : (day - 6) % CONTENT_TYPES.length]
  end

  def excluded_channel
    return @excluded_channel if defined?(@excluded_channel)
    previous = previous_videos.first
    @excluded_channel = previous&.fetch("channel", nil).presence
    if previous && @excluded_channel.nil?
      # Older cards did not persist their channel. Resolve only the latest card,
      # once per URL, rather than fetching the learner's entire import history.
      @excluded_channel = Rails.cache.fetch([ "daily-langlets-channel", previous.fetch("url") ], expires_in: 7.days) do
        VideoSource.fetch(previous.fetch("url")).author_name.presence
      end
    end
    @excluded_channel
  end

  def excluded?(url)
    @user.import_requests.where(youtube_video_id: Youtube::Url.video_id(url)).exists? || previous_urls.include?(url)
  end
end
