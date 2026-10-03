require "test_helper"

class DailyVideoRecommendationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "search-learner@example.test", password: "password123")
    @language = languages(:french)
    @url = "https://www.youtube.com/watch?v=kJQP7kiw5Fk"
  end

  test "requires search and sends bounded learning context without account identity" do
    entry = PhraseTokenUser.create_custom!(user: @user, sentence: "bonjour mon ami", language: @language,
      token_range: 0..0, translation: "hello", translation_language: languages(:english))
    client = Object.new
    client.define_singleton_method(:recommend_video) do |payload|
      raise "unexpected account data" if JSON.generate(payload).include?("search-learner")
      raise "missing word" unless payload[:vocabulary].first[:word] == entry.word
      { "url" => "https://youtu.be/kJQP7kiw5Fk", "search_suggestions" => "<div>Google Search</div>" }
    end
    result = DailyVideoRecommendation.new(user: @user, language: @language, client: client).call
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
    challenge.daily_challenges.create!(day: 6, language: @language, available_at: Time.zone.now, recommended_video: { "url" => @url })
    assert_raises(DailyVideoRecommendation::InvalidRecommendation) { recommend }
  end

  private

  def recommend(url: @url)
    client = Object.new
    client.define_singleton_method(:recommend_video) { |payload| { "url" => url } }
    DailyVideoRecommendation.new(user: @user, language: @language, client: client).call
  end
end
