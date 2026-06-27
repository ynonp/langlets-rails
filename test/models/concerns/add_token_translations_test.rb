require "test_helper"

class AddTokenTranslationsTest < ActiveSupport::TestCase
  setup do
    @phrases = [
      {
        "id" => "p1", "text_l1" => "avec une fille", "text_l2" => "with a girl",
        "words" => [
          { "text" => "avec", "timestamp" => "00:01.00", "timestamp_end" => "00:01.40" },
          { "text" => "une",  "timestamp" => "00:01.50", "timestamp_end" => "00:01.80" },
          { "text" => "fille", "timestamp" => "00:01.90", "timestamp_end" => "00:02.40" },
        ]
      },
      {
        "id" => "p2", "text_l1" => "trois jours", "text_l2" => "three days",
        "words" => [
          { "text" => "trois", "timestamp" => "00:03.00", "timestamp_end" => "00:03.40" },
          { "text" => "jours", "timestamp" => "00:03.50", "timestamp_end" => "00:03.90" },
        ]
      },
    ]

    @progress = CreateSongProgress.new(
      youtubeurl: "https://example.com/test",
      clip_language: "French",
      translation_language: "English",
      data: { "phrases" => @phrases }
    )

    @mock_responses = {
      "avec une fille" => "avec => with\nune => a\nfille => girl",
      "trois jours" => "trois => three\njours => days",
    }
  end

  test "writes a translation onto every word, in order" do
    stub_renderer!
    stub_translate_phrase_words!(mock_translate(@mock_responses))

    @progress.add_token_translation

    p1_words = @progress.data["phrases"][0]["words"]
    assert_equal %w[with a girl], p1_words.map { |w| w["translation"] }

    p2_words = @progress.data["phrases"][1]["words"]
    assert_equal %w[three days], p2_words.map { |w| w["translation"] }
  end

  test "ignores preamble lines and uses only word => translation lines" do
    translations = @progress.send(:parse_word_translations,
      "Here are the translations:\navec => with\nune => a\nfille => girl",
      %w[avec une fille])

    assert_equal %w[with a girl], translations
  end

  test "raises when translation count does not match word count" do
    error = assert_raises(RuntimeError) do
      @progress.send(:parse_word_translations, "avec => with\nune => a", %w[avec une fille])
    end
    assert_match(/count mismatch/, error.message)
  end

  test "skips phrases without words" do
    translations = @progress.send(:translate_phrase_words, "instructions", { "text_l1" => "x", "words" => [] }, 0)
    assert_equal [], translations
  end

  private

  def stub_renderer!
    renderer = ApplicationController.renderer
    renderer.define_singleton_method(:render) { |*args, **kwargs| "Test instructions" }
  end

  def stub_translate_phrase_words!(callable)
    @progress.define_singleton_method(:translate_phrase_words) do |instructions, phrase, max_retries|
      callable.call(instructions, phrase, max_retries)
    end
  end

  def mock_translate(responses)
    ->(instructions, phrase, max_retries) {
      raw = responses.fetch(phrase["text_l1"]) { raise "No mock response for: #{phrase["text_l1"].inspect}" }
      raw.lines.map { |l| l.split("=>", 2).last.strip }
    }
  end
end
