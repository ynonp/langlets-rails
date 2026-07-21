require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )

    @english = languages(:english)
    @spanish = languages(:spanish)
    @hebrew = languages(:hebrew)
    @arabic = languages(:arabic)

    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=test123",
      language: @english
    )

    @phrase_en = create_translated_phrase!(
      medium: @medium,
      l1: @english,
      l2: @spanish,
      text_l1: "Hello world",
      text_l2: "Hola mundo",
      timestamp: "00:01:30"
    )

    @phrase_ar = create_translated_phrase!(
      medium: @medium,
      l1: @arabic,
      l2: @english,
      text_l1: "مرحبا بالعالم",
      text_l2: "Hello world",
      timestamp: "00:02:00"
    )

    @phrase_he = create_translated_phrase!(
      medium: @medium,
      l1: @hebrew,
      l2: @english,
      text_l1: "שלום עולם",
      text_l2: "Hello world",
      timestamp: "00:03:00"
    )

    @token_en = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hola"
    )

    @token_ar = create_translated_token!(
      phrase: @phrase_ar,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )

    @token_he = create_translated_token!(
      phrase: @phrase_he,
      l1_start_index: 0,
      l1_end_index: 4,
      index_type: :character_index,
      translation: "Hi"
    )
  end

  test "ios language is stored without replacing other preferences" do
    @user.update!(theme: "light", ios_lang: "es")

    assert_equal "es", @user.reload.ios_lang
    assert_equal "light", @user.theme
  end

  test "languages_with_saved_words returns empty array when no saved words" do
    assert_equal [], @user.languages_with_saved_words
  end

  test "languages_with_saved_words returns distinct languages for saved tokens" do
    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar

    languages = @user.languages_with_saved_words.order(:iso_name)
    assert_equal 2, languages.count
    assert_equal [ @arabic.iso_name, @english.iso_name ], languages.map(&:iso_name)
  end

  test "languages_with_saved_words returns only unique languages" do
    token_en2 = create_translated_token!(
      phrase: @phrase_en,
      l1_start_index: 6,
      l1_end_index: 10,
      index_type: :character_index,
      translation: "Mundo"
    )

    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << token_en2

    languages = @user.languages_with_saved_words
    assert_equal 1, languages.count
    assert_equal @english.iso_name, languages.first.iso_name
  end

  test "saved_phrase_tokens_for_language returns empty when language not found" do
    assert_equal 0, @user.saved_phrase_tokens_for_language("nonexistent").count
  end

  test "saved_phrase_tokens_for_language returns tokens for specified language" do
    @user.saved_phrase_tokens << @token_en
    @user.saved_phrase_tokens << @token_ar
    @user.saved_phrase_tokens << @token_he

    en_tokens = @user.saved_phrase_tokens_for_language(@english.iso_name)
    ar_tokens = @user.saved_phrase_tokens_for_language(@arabic.iso_name)
    he_tokens = @user.saved_phrase_tokens_for_language(@hebrew.iso_name)

    assert_equal 1, en_tokens.count
    assert_equal 1, ar_tokens.count
    assert_equal 1, he_tokens.count

    assert_includes en_tokens, @token_en
    assert_includes ar_tokens, @token_ar
    assert_includes he_tokens, @token_he
  end

  test "saved_phrase_tokens_for_language filters by L1 language" do
    @user.saved_phrase_tokens << @token_en

    tokens = @user.saved_phrase_tokens_for_language(@english.iso_name)
    assert_equal 1, tokens.count
    assert_equal @token_en, tokens.first

    tokens = @user.saved_phrase_tokens_for_language(@spanish.iso_name)
    assert_equal 0, tokens.count
  end
end
