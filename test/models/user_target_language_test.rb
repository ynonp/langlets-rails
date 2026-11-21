require "test_helper"

# preferences["target_language"]: the language the user is learning, which the
# Dictionary translates into. Set explicitly, from the first imported video, or
# inferred from saved vocabulary.
class UserTargetLanguageTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "target@example.com", password: "password123", confirmed_at: Time.zone.now)
    @english = languages(:english)
    @spanish = languages(:spanish)
    @french = languages(:french)
    @japanese = languages(:japanese)
  end

  def save_word(language, text)
    phrase = @user.custom_phrases.create!(l1: language, text_l1: text)
    token = phrase.phrase_tokens.create!(l1_start_index: 0, l1_end_index: 1, index_type: :character_index)
    token.token_translations.create!(language: @english, translation: "x#{text}")
    @user.phrase_token_users.create!(phrase_token: token, language: @english)
  end

  def import(clip_language, video_id: SecureRandom.hex(4), status: :queued)
    ImportRequest.create!(user: @user, youtube_url: "https://www.youtube.com/watch?v=#{video_id}",
      youtube_video_id: video_id, clip_language: clip_language, translation_language: "en", status: status)
  end

  test "is unset by default and reads an unknown code as unset" do
    assert_nil @user.target_language

    @user.update!(preferences: { "target_language" => "xx" })
    assert_nil @user.target_language
  end

  test "stores the chosen language as its ISO code" do
    @user.target_language = @japanese
    @user.save!

    assert_equal "ja", @user.reload.preferences["target_language"]
    assert_equal @japanese, @user.target_language
  end

  test "adopting never overrides an existing choice" do
    @user.adopt_target_language!(@spanish)
    @user.adopt_target_language!(@french)

    assert_equal @spanish, @user.reload.target_language
  end

  test "adopting keeps the rest of the preferences" do
    @user.update!(preferences: { "theme" => "light", "native_language" => "he" })
    @user.adopt_target_language!(@spanish)

    assert_equal({ "theme" => "light", "native_language" => "he", "target_language" => "es" }, @user.reload.preferences)
  end

  test "infers the language most saved words are in" do
    save_word(@french, "le chat")
    save_word(@spanish, "el gato")
    save_word(@spanish, "la casa")

    assert_equal @spanish, @user.inferred_target_language
  end

  test "falls back to the language most imported videos are in" do
    import("fr")
    import("es")
    import("es")

    assert_equal @spanish, @user.inferred_target_language
  end

  test "saved words outrank imports, and nothing infers nothing" do
    assert_nil @user.inferred_target_language

    import("es")
    save_word(@french, "le chat")

    assert_equal @french, @user.inferred_target_language
  end

  test "the first imported video sets the target language" do
    import("ja")

    assert_equal @japanese, @user.reload.target_language
  end

  test "an import whose language is detected later sets it once detected" do
    request = ImportRequest.create!(user: @user, youtube_url: "https://www.youtube.com/watch?v=abc",
      youtube_video_id: "abc", translation_language: "en", status: :detecting)
    assert_nil @user.reload.target_language

    request.update!(clip_language: "es", status: :queued)
    assert_equal @spanish, @user.reload.target_language
  end

  test "a later import never replaces the target language" do
    @user.update!(preferences: { "target_language" => "fr" })
    import("es")

    assert_equal @french, @user.reload.target_language
  end
end
