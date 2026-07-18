require "test_helper"

class VocabularyQueryTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "vocab-query@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)
    @arabic = languages(:arabic)

    @medium = Medium.create!(url: "https://www.youtube.com/watch?v=vq1", language: @english)

    @phrase_en = create_translated_phrase!(
      medium: @medium, l1: @english, l2: @spanish,
      text_l1: "Hello world", text_l2: "Hola mundo", timestamp: "00:01:30"
    )
    @phrase_ar = create_translated_phrase!(
      medium: @medium, l1: @arabic, l2: @english,
      text_l1: "مرحبا بالعالم", text_l2: "Hello world", timestamp: "00:02:00"
    )

    @token_en = create_translated_token!(
      phrase: @phrase_en, l1_start_index: 0, l1_end_index: 4,
      index_type: :character_index, translation: "Hola"
    )
    @token_ar = create_translated_token!(
      phrase: @phrase_ar, l1_start_index: 0, l1_end_index: 4,
      index_type: :character_index, translation: "Hi"
    )
  end

  test "returns word, translation and context for saved tokens" do
    @user.saved_phrase_tokens << @token_en

    result = VocabularyQuery.new(user: @user).call

    assert_equal 1, result[:items].size
    item = result[:items].first
    assert_equal "Hello", item[:word]
    assert_equal "Hola", item[:translation]
    assert_equal "en", item[:language]
    assert_equal "Hello world", item[:context]
    assert_equal "Hola mundo", item[:context_translation]
    assert item[:saved_at].present?
    assert_equal false, result[:has_more]
  end

  test "only returns the user's own saved tokens" do
    other = User.create!(email: "other-vocab@example.com", password: "password123", confirmed_at: Time.zone.now)
    other.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar

    result = VocabularyQuery.new(user: @user).call

    assert_equal [ "Hi" ], result[:items].map { |i| i[:translation] }
  end

  test "filters by language iso code" do
    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar

    result = VocabularyQuery.new(user: @user, language: "ar-JO").call

    assert_equal 1, result[:items].size
    assert_equal "ar-JO", result[:items].first[:language]
  end

  test "raises for unknown language code" do
    assert_raises(PaginatedQuery::UnknownLanguageError) do
      VocabularyQuery.new(user: @user, language: "nope").call
    end
  end

  test "paginates with exact has_more" do
    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar

    page1 = VocabularyQuery.new(user: @user, page: 1, per_page: 1).call
    page2 = VocabularyQuery.new(user: @user, page: 2, per_page: 1).call

    assert_equal 1, page1[:items].size
    assert page1[:has_more]
    assert_equal 1, page2[:items].size
    assert_not page2[:has_more]
    assert_not_equal page1[:items].first[:word], page2[:items].first[:word]
  end

  test "clamps page and per_page" do
    result = VocabularyQuery.new(user: @user, page: -3, per_page: 100_000).call

    assert_equal 1, result[:page]
    assert_equal PaginatedQuery::MAX_PER_PAGE, result[:per_page]
  end
end
