require "test_helper"

class MediumTest < ActiveSupport::TestCase
  URL = "https://www.youtube.com/watch?v=collide1234".freeze

  setup do
    @spanish = languages(:spanish)
    @english = languages(:english)
    @hebrew  = languages(:hebrew)
  end

  test "the same video has one transcription for all translation languages" do
    medium = Medium.create!(url: URL, language: @spanish)
    phrase = Phrase.create!(medium: medium, l1: @spanish, text_l1: "hola", timestamp: "00:01")
    phrase.phrase_translations.create!(language: @english, text: "hello")
    phrase.phrase_translations.create!(language: @hebrew, text: "שלום")

    assert_equal 1, Medium.where(url: URL, language: @spanish).count
    assert_equal 2, phrase.phrase_translations.count
  end

  test "a video is unique per clip language" do
    Medium.create!(url: URL, language: @spanish)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Medium.create!(url: URL, language: @spanish)
    end
  end

  # The regression. When a medium was keyed on URL alone, importing a video for a
  # second translation language reused the first course's medium, and
  # CourseBuilder::BuildSong's `medium.phrases.destroy_all` wiped the published
  # course's phrases.
  test "adding a translation leaves the shared phrase intact" do
    medium = Medium.create!(url: URL, language: @spanish)
    phrase = Phrase.create!(medium: medium, l1: @spanish, text_l1: "hola", timestamp: "00:01")
    phrase.phrase_translations.create!(language: @english, text: "hello")
    phrase.phrase_translations.create!(language: @hebrew, text: "שלום")

    assert_equal 1, medium.phrases.reload.count
    assert_equal "hola", phrase.reload.text_l1
  end

  test "phrases resolve through Current translation language" do
    medium = Medium.create!(url: URL, language: @spanish)
    phrase = Phrase.create!(medium: medium, l1: @spanish, text_l1: "hola", timestamp: "00:01")
    phrase.phrase_translations.create!(language: @english, text: "hello")
    phrase.phrase_translations.create!(language: @hebrew, text: "שלום")

    Current.translation_language = @english
    assert_equal "hello", phrase.reload.text_l2
    Current.translation_language = @hebrew
    assert_equal "שלום", phrase.reload.text_l2
  ensure
    Current.reset
  end

  test "destroying a medium destroys its lessons, phrases, and phrase resources" do
    user = User.create!(
      email: "medium-destroy@example.com",
      password: "password123",
      confirmed_at: Time.zone.now
    )
    medium = Medium.create!(url: URL, language: @spanish)
    other_medium = Medium.create!(url: "https://www.youtube.com/watch?v=other12345", language: @spanish)
    lesson = Lesson.create!(medium: medium, user: user, name: "Owned lesson")
    other_lesson = Lesson.create!(medium: other_medium, user: user, name: "Other lesson")
    owned_activity = Activities::WatchVideoActivity.create!(lesson: lesson, user: user)
    other_activity = Activities::WatchVideoActivity.create!(lesson: other_lesson, user: user)
    activity_log = ActivityLog.create!(lesson: lesson, user: user, active_time: 10, xp_gained: 5)

    phrase = Phrase.create!(medium: medium, l1: @spanish, text_l1: "hola", timestamp: "00:01")
    translation = phrase.phrase_translations.create!(language: @english, text: "hello")
    similar_sound = phrase.similar_sounds.create!(start_word_index: 0, end_word_index: 0, replacement_text: "ola")
    token = phrase.phrase_tokens.create!(
      l1_start_index: 0,
      l1_end_index: 0,
      index_type: :word_index
    )
    token_translation = token.token_translations.create!(
      language: @english,
      translation: "hello",
      l2_start_index: 0,
      l2_end_index: 0
    )
    saved_token = token.phrase_token_users.create!(user: user, language: @english)
    phrase_join = ActivityPhrase.create!(activity: other_activity, phrase: phrase)
    token_join = ActivityPhraseToken.create!(activity: other_activity, phrase_token: token)

    medium.destroy!

    assert_not Medium.exists?(medium.id)
    assert_not Lesson.exists?(lesson.id)
    assert_not Activity.exists?(owned_activity.id)
    assert_not Phrase.exists?(phrase.id)
    assert_not PhraseTranslation.exists?(translation.id)
    assert_not SimilarSound.exists?(similar_sound.id)
    assert_not PhraseToken.exists?(token.id)
    assert_not TokenTranslation.exists?(token_translation.id)
    assert_not PhraseTokenUser.exists?(saved_token.id)
    assert_not ActivityPhrase.exists?(phrase_join.id)
    assert_not ActivityPhraseToken.exists?(token_join.id)
    assert_nil activity_log.reload.lesson_id

    assert Medium.exists?(other_medium.id)
    assert Lesson.exists?(other_lesson.id)
    assert Activity.exists?(other_activity.id)
  end
end
