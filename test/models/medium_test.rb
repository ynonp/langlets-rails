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
end
