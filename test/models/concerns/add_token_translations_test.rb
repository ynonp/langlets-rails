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

    @dictionary = {
      "avec" => "with", "une" => "a", "fille" => "girl",
      "trois" => "three", "jours" => "days",
    }
  end

  test "writes a translation onto every word, in order" do
    stub_renderer!
    stub_translate_chunk!(mock_translate(@dictionary))

    @progress.add_token_translation

    p1_words = @progress.data["phrases"][0]["words"]
    assert_equal %w[with a girl], p1_words.map { |w| w["translation"] }

    p2_words = @progress.data["phrases"][1]["words"]
    assert_equal %w[three days], p2_words.map { |w| w["translation"] }
  end

  test "builds one input line per word marking the target in its phrase context" do
    line = @progress.send(:build_word_line, @phrases[0], 1)
    assert_equal "une (avec *une* fille) |", line
  end

  test "parse_chunk_translations ignores lines without a pipe and reads the translation after it" do
    translations = @progress.send(:parse_chunk_translations,
      "Here are the translations:\navec (..) | with\nune (..) | a\nfille (..) | girl",
      3)

    assert_equal %w[with a girl], translations
  end

  test "parse_chunk_translations raises when translation count does not match" do
    error = assert_raises(RuntimeError) do
      @progress.send(:parse_chunk_translations, "avec (..) | with\nune (..) | a", 3)
    end
    assert_match(/count mismatch/, error.message)
  end

  test "batches all words across phrases into 200-line chunks" do
    stub_renderer!

    chunk_sizes = []
    @progress.define_singleton_method(:translate_chunk) do |instructions, chunk, max_retries|
      chunk_sizes << chunk.size
      chunk.map { |entry| [ entry, "x" ] }
    end

    # 5 words total -> a single chunk
    @progress.add_token_translation
    assert_equal [ 5 ], chunk_sizes
  end

  test "saves without error when there are no words" do
    @progress.data["phrases"] = [ { "id" => "p1", "text_l1" => "x", "text_l2" => "y", "words" => [] } ]
    stub_renderer!

    assert_nothing_raised { @progress.add_token_translation }
  end

  private

  def stub_renderer!
    renderer = ApplicationController.renderer
    renderer.define_singleton_method(:render) { |*args, **kwargs| "Test instructions" }
  end

  def stub_translate_chunk!(callable)
    @progress.define_singleton_method(:translate_chunk) do |instructions, chunk, max_retries|
      callable.call(instructions, chunk, max_retries)
    end
  end

  # Maps each chunk entry to [entry, translation] by looking up the target word
  # (the text before the " (" context) in the dictionary.
  def mock_translate(dictionary)
    ->(instructions, chunk, max_retries) {
      chunk.map do |entry|
        word = entry[:line].split(" (", 2).first
        [ entry, dictionary.fetch(word) ]
      end
    }
  end
end
