require "test_helper"

class MultiLanguageTranslationTest < ActiveSupport::TestCase
  setup do
    @english = languages(:english)
    @hebrew = languages(:hebrew)
    @spanish = languages(:spanish)
    @medium = Medium.create!(url: "https://www.youtube.com/watch?v=multiL2test", language: @spanish)
    @phrase = Phrase.create!(medium: @medium, l1: @spanish, text_l1: "cielo azul", timestamp: "00:01")
    @phrase.phrase_translations.create!(language: @english, text: "blue sky")
    @phrase.phrase_translations.create!(language: @hebrew, text: "שמיים כחולים")
    @token = @phrase.phrase_tokens.create!(
      l1_start_index: 6, l1_end_index: 9, index_type: :character_index
    )
    @token.token_translations.create!(language: @english, translation: "blue")
    @token.token_translations.create!(language: @hebrew, translation: "כחולים")
  end

  teardown { Current.reset }

  test "one transcription resolves phrase and token text in the request language" do
    Current.translation_language = @english
    assert_equal "blue sky", @phrase.reload.text_l2
    assert_equal "blue", @token.reload.translation

    Current.translation_language = @hebrew
    assert_equal "שמיים כחולים", @phrase.reload.text_l2
    assert_equal "כחולים", @token.reload.translation
    assert_equal 1, Medium.where(url: @medium.url, language: @spanish).count
  end

  test "saving a span pins and updates its translation language" do
    user = User.create!(email: "language-pin@example.com", password: "password123", confirmed_at: Time.zone.now)
    Current.translation_language = @hebrew
    saved = user.phrase_token_users.create!(phrase_token: @token)
    assert_equal @hebrew, saved.language
    assert_equal "כחולים", saved.token_translation.translation

    Current.translation_language = @english
    saved.update!(language: Current.translation_language)
    assert_equal @english, saved.reload.language
    assert_equal "blue", saved.token_translation.translation
    assert_equal 1, user.phrase_token_users.where(phrase_token: @token).count
  end

  test "saving a span falls back when the preferred translation is unavailable" do
    user = User.create!(email: "fallback-pin@example.com", password: "password123", confirmed_at: Time.zone.now)
    english_only = @phrase.phrase_tokens.create!(
      l1_start_index: 0, l1_end_index: 4, index_type: :character_index
    )
    english_only.token_translations.create!(language: @english, translation: "sky")

    Current.set(translation_language: languages(:arabic)) do
      saved = user.phrase_token_users.create!(phrase_token: english_only)

      assert_equal @english, saved.language
      assert_equal "sky", saved.translation
    end
  end

  test "activities store the neutral span once" do
    user = User.create!(email: "span-activity@example.com", password: "password123", confirmed_at: Time.zone.now)
    course = Course.create!(name: "Course", slug: "multi-course", main_media_url: @medium.url, language: @spanish, user: user)
    lesson = Lesson.create!(name: "Lesson", course: course, medium: @medium, user: user)
    activity = Activities::FlashcardActivity.create!(lesson: lesson, user: user)
    activity.phrase_tokens = [ @token ]

    assert_equal [ @token.id ], activity.reload.phrase_tokens.ids
    assert_equal 1, ActivityPhraseToken.where(activity: activity, phrase_token: @token).count
  end

  test "adding a translation leaves the shared skeleton and progress untouched" do
    german = languages(:arabic)
    user = User.create!(email: "translation-only@example.com", password: "password123", confirmed_at: Time.zone.now)
    progress = CreateSongProgress.create!(
      youtubeurl: @medium.url,
      clip_language: @spanish.english_name,
      data: {
        "translations" => {
          german.iso_name => {
            "phrases" => [ { "text" => "blauer Himmel", "words" => [ "blau" ] } ],
            "lessons" => "# Erste Lektion\n00:01 cielo azul"
          }
        }
      }
    )
    course = Course.create!(
      name: "Shared", slug: "shared-skeleton", main_media_url: @medium.url,
      language: @spanish, user: user, create_song_progress: progress
    )
    lesson = Lesson.create!(name: "Lesson", course: course, medium: @medium, user: user)
    activity = Activities::FlashcardActivity.create!(lesson: lesson, user: user)
    activity.phrase_tokens = [ @token ]
    user.phrase_token_users.create!(phrase_token: @token, language: @english)

    counts = [ course.lessons.count, Activity.where(lesson: course.lessons).count, PhraseTokenUser.count ]
    CourseBuilder::BuildSong.new(progress, course).add_translation(german)

    assert_equal counts, [ course.lessons.count, Activity.where(lesson: course.lessons).count, PhraseTokenUser.count ]
    assert_equal "blauer Himmel", @phrase.phrase_translations.find_by!(language: german).text
    assert_equal "blau", @token.token_translations.find_by!(language: german).translation
    assert course.course_translations.find_by!(language: german).ready?
  end
end
