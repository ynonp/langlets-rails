# Gemini searches on the pipeline host using its existing Google key. Only
# bounded learning context leaves Rails; the pipeline verifies search sources.
class DailyVideoRecommendation
  class InvalidRecommendation < StandardError; end

  def self.call(...) = new(...).call

  Result = Data.define(:url, :search_suggestions)

  def initialize(user:, language:, client: PipelineClient)
    @user, @language, @client = user, language, client
  end

  def call
    response = @client.recommend_video(context)
    url = canonical_video(response.fetch("url"))
    raise InvalidRecommendation, "No verified new video found" unless url && !excluded?(url)
    Result.new(url: url, search_suggestions: response["search_suggestions"])
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
    imports = @user.import_requests.ready.where(clip_language: @language.english_name)
      .recent_first.limit(8).pluck(:title, :youtube_url)
    words = @user.phrase_token_users.practising.joins(phrase_token: :phrase)
      .where(phrases: { l1_id: @language.id }).order(created_at: :desc).limit(40)
      .includes(phrase_token: [ :phrase, :token_translations ])
    { learning_language: @language.english_name,
      imported_videos: imports.map { |title, url| { title: title.to_s.truncate(200), url: url } },
      vocabulary: words.map { |entry| { word: entry.word.to_s.truncate(100), translation: entry.translation.to_s.truncate(100) } },
      previous_suggestions: previous_urls }
  end

  def previous_urls
    @previous_urls ||= DailyChallenge.where(starter_challenge_id: @user.starter_challenge&.id).where("day > 5")
      .order(day: :desc).limit(30).pluck(:recommended_video).filter_map { |video| video["url"] }
  end

  def excluded?(url)
    @user.import_requests.where(youtube_video_id: Youtube::Url.video_id(url)).exists? || previous_urls.include?(url)
  end
end
