require "test_helper"

class CreateSongExtractLyricsTest < ActiveSupport::TestCase
  setup do
    @progress = CreateSongProgress.new(
      youtubeurl: "https://example.com/test",
      clip_language: "French",
      translation_language: "English"
    )

    @word_timing_json = <<~JSON
      [
        {
          "line_start": "00:00:05,000",
          "line_end": "00:00:08,000",
          "line_text": "First line",
          "words": [
            { "word": "First", "start": "00:00:05,000", "end": "00:00:06,200" },
            { "word": "line", "start": "00:00:06,400", "end": "00:00:08,000" }
          ]
        },
        {
          "line_start": "00:00:25,000",
          "line_end": "00:00:28,500",
          "line_text": "Second line here",
          "words": [
            { "word": "Second", "start": "00:00:25,000", "end": "00:00:26,000" },
            { "word": "line", "start": "00:00:26,200", "end": "00:00:27,000" },
            { "word": "here", "start": "00:00:27,200", "end": "00:00:28,500" }
          ]
        }
      ]
    JSON
  end

  test "extract_lyrics parses word-timed JSON into phrases with words" do
    fake_chat = FakeChatQueue.new([ @word_timing_json ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    phrases = @progress.data["phrases"]
    assert_equal 2, phrases.length

    assert_equal "First line", phrases[0]["text_l1"]
    assert_equal "00:05.00", phrases[0]["timestamp"]
    assert_equal "00:08.00", phrases[0]["timestamp_end"]

    words = phrases[0]["words"]
    assert_equal 2, words.length
    assert_equal "First", words[0]["text"]
    assert_equal "00:05.00", words[0]["timestamp"]
    assert_equal "00:06.20", words[0]["timestamp_end"]
    assert_equal "line", words[1]["text"]

    assert_equal 1, fake_chat.call_count
  end

  test "extract_lyrics handles empty JSON gracefully" do
    fake_chat = FakeChatQueue.new([ "[]" ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal [], @progress.data["phrases"]
  end

  # ── WordTimingParser ─────────────────────────────────────────────────

  test "WordTimingParser strips code fences and square brackets" do
    fenced = "```json\n[{\"line_start\":\"00:00:01,000\",\"line_end\":\"00:00:02,000\",\"line_text\":\"a [b] c\",\"words\":[{\"word\":\"a\",\"start\":\"00:00:01,000\",\"end\":\"00:00:01,500\"}]}]\n```"

    phrases = WordTimingParser.parse(fenced)

    assert_equal 1, phrases.length
    assert_equal "a (b) c", phrases[0]["text_l1"]
    assert_equal "00:01.00", phrases[0]["timestamp"]
  end

  test "WordTimingParser falls back to joined words when line_text missing" do
    json = "[{\"line_start\":\"00:00:01,000\",\"line_end\":\"00:00:02,000\",\"words\":[{\"word\":\"hello\",\"start\":\"00:00:01,000\",\"end\":\"00:00:01,400\"},{\"word\":\"world\",\"start\":\"00:00:01,500\",\"end\":\"00:00:02,000\"}]}]"

    phrases = WordTimingParser.parse(json)

    assert_equal "hello world", phrases[0]["text_l1"]
  end

  private

  # Temporarily intercept TracedChat.new to return a fake chat.
  def with_fake_chat(fake_chat, &block)
    original_new = TracedChat.method(:new)
    TracedChat.define_singleton_method(:new) do |**kwargs|
      if kwargs[:span_name].to_s.start_with?("extract_lyrics")
        fake_chat
      else
        original_new.call(**kwargs)
      end
    end
    block.call
  ensure
    TracedChat.define_singleton_method(:new, original_new) rescue nil
  end

  def stub_renderer_for_extract_lyrics!
    renderer = ApplicationController.renderer
    renderer.define_singleton_method(:render) { |*args, **kwargs| "Test instructions" }
  end

  # A fake chat that returns queued responses for .complete calls,
  # and returns self for all chained methods.
  class FakeChatQueue
    attr_reader :call_count, :all_messages

    def initialize(responses)
      @responses = responses
      @call_count = 0
      @all_messages = []
    end

    def with_instructions(*)
      self
    end

    def with_temperature(*)
      self
    end

    def add_message(*args)
      @all_messages << args
      self
    end

    def complete
      resp = @responses[@call_count]
      @call_count += 1
      FakeResponse.new(resp)
    end
  end

  # Minimal stub with a .content accessor, like RubyLLM response objects.
  FakeResponse = Struct.new(:content)
end
