require "test_helper"

class MediumTest < ActiveSupport::TestCase
  URL = "https://www.youtube.com/watch?v=collide1234".freeze

  setup do
    @spanish = languages(:spanish)
    @english = languages(:english)
    @hebrew  = languages(:hebrew)
  end

  test "the same video can be transcribed into two translation languages" do
    es_en = Medium.create!(url: URL, language: @spanish, translation_language: @english)
    es_he = Medium.create!(url: URL, language: @spanish, translation_language: @hebrew)

    assert_not_equal es_en.id, es_he.id
  end

  test "a video is unique per language pair" do
    Medium.create!(url: URL, language: @spanish, translation_language: @english)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Medium.create!(url: URL, language: @spanish, translation_language: @english)
    end
  end

  # The regression. When a medium was keyed on URL alone, importing a video for a
  # second translation language reused the first course's medium, and
  # CourseBuilder::BuildSong's `medium.phrases.destroy_all` wiped the published
  # course's phrases.
  test "rebuilding one language pair leaves the other pair's phrases intact" do
    es_en = Medium.create!(url: URL, language: @spanish, translation_language: @english)
    es_he = Medium.create!(url: URL, language: @spanish, translation_language: @hebrew)

    Phrase.create!(medium: es_en, l1: @spanish, l2: @english,
                   text_l1: "hola", text_l2: "hello", timestamp: "00:01")
    Phrase.create!(medium: es_he, l1: @spanish, l2: @hebrew,
                   text_l1: "hola", text_l2: "שלום", timestamp: "00:01")

    es_he.phrases.destroy_all

    assert_equal 1, es_en.phrases.reload.count
    assert_equal "hello", es_en.phrases.first.text_l2
  end

  test "phrases read back scoped to their own language pair" do
    es_en = Medium.create!(url: URL, language: @spanish, translation_language: @english)
    es_he = Medium.create!(url: URL, language: @spanish, translation_language: @hebrew)

    Phrase.create!(medium: es_en, l1: @spanish, l2: @english,
                   text_l1: "hola", text_l2: "hello", timestamp: "00:01")
    Phrase.create!(medium: es_he, l1: @spanish, l2: @hebrew,
                   text_l1: "hola", text_l2: "שלום", timestamp: "00:01")

    # FullPlayerController and the activity builders all read `medium.phrases`
    # and assume it means "this course's phrases".
    assert_equal [ @english.id ], es_en.phrases.reload.pluck(:l2_id).uniq
    assert_equal [ @hebrew.id ],  es_he.phrases.reload.pluck(:l2_id).uniq
  end
end
