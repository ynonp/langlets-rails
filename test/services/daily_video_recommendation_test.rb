require "test_helper"

class DailyVideoRecommendationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "search-learner@example.test", password: "password123")
    @language = languages(:french)
    @preflight = Object.new
    video = VideoSource::Video.new(video_id: "kJQP7kiw5Fk", title: "French dialogue", author_name: "New creator",
      thumbnail_url: nil, canonical_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk")
    @preflight.define_singleton_method(:call) { |url| Imports::VideoPreflight::Result.new(video: video, duration_seconds: 180, maximum_duration_seconds: 1500) }
    @url = "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
  end

  test "requires search and sends bounded learning context without account identity" do
    entry = PhraseTokenUser.create_custom!(user: @user, sentence: "bonjour mon ami", language: @language,
      token_range: 0..0, translation: "hello", translation_language: languages(:english))
    client = Object.new
    client.define_singleton_method(:recommend_video) do |payload|
      raise "unexpected account data" if JSON.generate(payload).include?("search-learner")
      raise "missing word" unless payload[:vocabulary].first[:word] == entry.word
      { "url" => "https://youtu.be/kJQP7kiw5Fk", "search_suggestions" => "<div>Google Search</div>", "content_type" => payload[:preferred_content_type] }
    end
    result = DailyVideoRecommendation.new(user: @user, language: @language, client: client, preflight: @preflight).call
    assert_equal @url, result.url
    assert_equal "<div>Google Search</div>", result.search_suggestions
  end

  test "rejects malformed video URLs from the pipeline" do
    [ "https://evil.example/youtube.com/watch?v=kJQP7kiw5Fk", nil ].each do |url|
      assert_raises(DailyVideoRecommendation::InvalidRecommendation) { recommend(url: url) }
    end
  end

  test "does not recommend an already imported video" do
    @user.import_requests.create!(youtube_url: @url, youtube_video_id: "kJQP7kiw5Fk",
      clip_language: "French", translation_language: "English", status: :ready)
    assert_raises(DailyVideoRecommendation::InvalidRecommendation) { recommend }
  end

  test "does not repeat a recent suggestion" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [ @language.id ], delivery: [])
    challenge.daily_challenges.create!(day: 6, language: @language, available_at: Time.zone.now, recommended_video: { "url" => @url, "channel" => "Old creator" })
    assert_raises(DailyVideoRecommendation::InvalidRecommendation) { recommend }
  end

  test "rotates types across languages and passes the latest channel and recent topics" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [ @language.id ], delivery: [])
    previous = challenge.daily_challenges.create!(day: 6, language: languages(:spanish), available_at: Time.zone.now,
      recommended_video: { "url" => "https://www.youtube.com/watch?v=abcdefghijk", "title" => "Market dialogue",
        "content_type" => "dialogue", "channel" => "Old creator" })
    { "dialogue" => "song", "song" => "story", "story" => "culture", "culture" => "dialogue" }.each do |last, target|
      previous.update!(recommended_video: previous.recommended_video.merge("content_type" => last))
      test_case = self
      client = Object.new
      client.define_singleton_method(:recommend_video) do |payload|
        test_case.assert_equal target, payload[:preferred_content_type]
        test_case.assert_equal "Old creator", payload[:excluded_channel]
        test_case.assert_equal "Market dialogue", payload[:recent_recommendations].first[:title]
        { "url" => "https://www.youtube.com/watch?v=kJQP7kiw5Fk", "content_type" => target }
      end
      result = DailyVideoRecommendation.new(user: @user, language: @language, client: client, preflight: @preflight).call
      assert_equal target, result.content_type
      assert_equal "New creator", result.video.author_name
    end
  end

  test "rejects a repeated channel despite a valid grounded URL" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [ @language.id ], delivery: [])
    challenge.daily_challenges.create!(day: 6, language: @language, available_at: Time.zone.now,
      recommended_video: { "url" => "https://www.youtube.com/watch?v=abcdefghijk", "channel" => " NEW  CREATOR ", "content_type" => "dialogue" })
    assert_raises(DailyVideoRecommendation::InvalidRecommendation) { recommend }
  end

  test "resolves the previous channel for legacy cards without saved metadata" do
    challenge = StarterChallenge.enroll!(user: @user, language_ids: [ @language.id ], delivery: [])
    challenge.daily_challenges.create!(day: 6, language: @language, available_at: Time.zone.now,
      recommended_video: { "url" => "https://www.youtube.com/watch?v=abcdefghijk" })
    old_video = @preflight.call(@url).video.with(author_name: "New creator")
    VideoSource.stub(:fetch, old_video) do
      assert_raises(DailyVideoRecommendation::InvalidRecommendation) { recommend }
    end
  end

  test "rejects a different content type than requested" do
    client = Object.new
    client.define_singleton_method(:recommend_video) { |_| { "url" => "https://www.youtube.com/watch?v=kJQP7kiw5Fk", "content_type" => "invalid" } }
    assert_raises(DailyVideoRecommendation::InvalidRecommendation) do
      DailyVideoRecommendation.new(user: @user, language: @language, client: client, preflight: @preflight).call
    end
  end

  test "samples source words from the learner's imported videos when vocabulary is empty" do
    course = Course.create!(user: @user, language: @language, name: "French story", slug: "daily-vocabulary-story",
      main_media_url: "https://www.youtube.com/watch?v=abcdefghijk", youtube_video_id: "abcdefghijk", status: :published)
    medium = Medium.create!(url: course.main_media_url, language: @language)
    course.lessons.create!(user: @user, medium: medium)
    Phrase.create!(medium: medium, l1: @language, text_l1: "Bonjour, boulangerie pain acheter!")
    Phrase.create!(medium: medium, l1: languages(:english), text_l1: "unrelatedEnglishWord")
    @user.import_requests.create!(youtube_url: course.main_media_url, youtube_video_id: course.youtube_video_id,
      clip_language: "French", translation_language: "English", status: :ready, course: course)
    payload = DailyVideoRecommendation.new(user: @user, language: @language).send(:context)
    assert_equal %w[Bonjour acheter boulangerie pain], payload[:vocabulary].map { |entry| entry[:word] }.sort
    assert payload[:vocabulary].all? { |entry| entry[:translation] == "" }
    assert_operator payload[:vocabulary].size, :<=, 40
  end

  test "no vocabulary and no imports send empty words without invented examples" do
    payload = DailyVideoRecommendation.new(user: @user, language: @language).send(:context)
    assert_empty payload[:vocabulary]
  end

  private

  def recommend(url: @url)
    client = Object.new
    client.define_singleton_method(:recommend_video) { |payload| { "url" => url, "content_type" => payload[:preferred_content_type] } }
    DailyVideoRecommendation.new(user: @user, language: @language, client: client, preflight: @preflight).call
  end
end
