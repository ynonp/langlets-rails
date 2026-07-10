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

  test "extract_lyrics pages through the video until has_more is false" do
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 2), "has_more" => true },
      { "lines" => lines_batch(3, 4), "has_more" => false }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    phrases = @progress.data["phrases"]
    assert_equal 4, phrases.length
    assert_equal %w[phrase_1 phrase_2 phrase_3 phrase_4], phrases.map { |p| p["id"] }
    assert_equal [ "Line 1", "Line 2", "Line 3", "Line 4" ], phrases.map { |p| p["text_l1"] }

    assert_equal 2, fake_chat.call_count
    # The second turn is driven by a continuation message referencing the last line.
    continuation = fake_chat.all_messages.last
    assert_match(/Continue transcribing/, continuation.last[:content])
    assert_match(/Line 2/, continuation.last[:content])
  end

  test "extract_lyrics dedups overlapping lines across batches" do
    # Batch 2 re-sends line 3 (overlap) plus two genuinely new lines.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 3), "has_more" => true },
      { "lines" => lines_batch(3, 5), "has_more" => false }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    phrases = @progress.data["phrases"]
    # Line 3 appears once, not twice.
    assert_equal [ "Line 1", "Line 2", "Line 3", "Line 4", "Line 5" ], phrases.map { |p| p["text_l1"] }
    assert_equal %w[phrase_1 phrase_2 phrase_3 phrase_4 phrase_5], phrases.map { |p| p["id"] }
    assert_equal 2, fake_chat.call_count
  end

  test "extract_lyrics stops when has_more is true but the batch is entirely overlap" do
    # Second turn claims more content but only re-sends lines we already have.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 3), "has_more" => true },
      { "lines" => lines_batch(2, 3), "has_more" => true }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal 3, @progress.data["phrases"].length
    assert_equal 2, fake_chat.call_count
  end

  test "extract_lyrics drops continuation lines with a timestamp before the last accepted line" do
    # Batch 2 leads with a line whose timestamp (sec 2) is BEFORE the last line
    # we already have (sec 3) and whose text is new, so exact-match dedup would
    # not catch it -- the backwards filter must.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 3), "has_more" => true },
      { "lines" => [ line_hash("Sneaky backwards line", 2), *lines_batch(4, 5) ], "has_more" => false }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    texts = @progress.data["phrases"].map { |p| p["text_l1"] }
    assert_equal [ "Line 1", "Line 2", "Line 3", "Line 4", "Line 5" ], texts
    refute_includes texts, "Sneaky backwards line"
  end

  test "extract_lyrics stops when a whole continuation batch is backwards" do
    # Every line in batch 2 predates the last accepted line -> nothing admitted ->
    # no forward progress -> stop, even though has_more stays true.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(3, 5), "has_more" => true },
      { "lines" => [ line_hash("Old A", 1), line_hash("Old B", 2) ], "has_more" => true }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal [ "Line 3", "Line 4", "Line 5" ], @progress.data["phrases"].map { |p| p["text_l1"] }
    assert_equal 2, fake_chat.call_count
  end

  test "extract_lyrics keeps a repeated chorus line at a later timestamp" do
    # Same text as an earlier line but at a LATER timestamp (sec 6 > cutoff 3) is a
    # legitimate repeat and must be kept.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 3), "has_more" => true },
      { "lines" => [ line_hash("Line 1", 6) ], "has_more" => false }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    texts = @progress.data["phrases"].map { |p| p["text_l1"] }
    # "Line 1" appears twice: once at 00:01 and again as the later chorus at 00:06.
    assert_equal 4, texts.length
    assert_equal 2, texts.count("Line 1")
  end

  test "extract_lyrics stops when has_more is true but the batch is empty" do
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 2), "has_more" => true },
      { "lines" => [], "has_more" => true }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal 2, @progress.data["phrases"].length
    assert_equal 2, fake_chat.call_count
  end

  test "extract_lyrics caps continuation turns even if has_more never becomes false" do
    # Every turn adds a genuinely new line and keeps claiming there is more, so
    # only the safety cap can stop the loop.
    endless = (1..40).map { |n| { "lines" => lines_batch(n, n), "has_more" => true } }
    fake_chat = FakeChatQueue.new(endless)

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    max_turns = CreateSongProgress::MAX_CONTINUATION_TURNS + 1
    assert_equal max_turns, fake_chat.call_count
    assert_equal max_turns, @progress.data["phrases"].length
  end

  test "extract_lyrics stops when a continuation turn adds no new phrases" do
    # has_more stays true forever, but the model keeps re-emitting the same line.
    duplicate = { "lines" => lines_batch(1, 1), "has_more" => true }
    fake_chat = FakeChatQueue.new([ duplicate, duplicate, duplicate ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal 1, @progress.data["phrases"].length
    # First call returns the line, second call adds nothing new -> stop.
    assert_equal 2, fake_chat.call_count
  end

  test "extract_lyrics handles empty JSON gracefully" do
    fake_chat = FakeChatQueue.new([ "[]" ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal [], @progress.data["phrases"]
  end

  test "extract_lyrics raises when less than half the video is transcribed" do
    # Lines reach 00:03 but the model says the video is 00:10 long -> 30% covered.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 3), "has_more" => false, "video_length" => "00:00:10,000" }
    ])

    stub_renderer_for_extract_lyrics!
    error = assert_raises(CreateSong::ExtractLyrics::IncompleteTranscriptionError) do
      with_fake_chat(fake_chat) { @progress.extract_lyrics }
    end
    assert_match(/30%/, error.message)
  end

  test "extract_lyrics succeeds when at least half the video is transcribed" do
    # Lines reach 00:06 against a 00:10 video -> 60% covered.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 6), "has_more" => false, "video_length" => "00:00:10,000" }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal 6, @progress.data["phrases"].length
  end

  test "extract_lyrics tolerates a missing video_length" do
    # No length reported -> coverage can't be judged -> don't fail on metadata.
    fake_chat = FakeChatQueue.new([
      { "lines" => lines_batch(1, 2), "has_more" => false }
    ])

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    assert_equal 2, @progress.data["phrases"].length
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

  # Build a single "line" hash (schema shape) with the given text at second `sec`.
  def line_hash(text, sec)
    ts = format("00:00:%02d,000", sec)
    {
      "line_start" => ts,
      "line_end" => ts,
      "line_text" => text,
      "words" => [ { "word" => text.split.first, "start" => ts, "end" => ts } ]
    }
  end

  # Build a "lines" array for line numbers first..last, "Line N" at second N.
  def lines_batch(first, last)
    (first..last).map { |n| line_hash("Line #{n}", n) }
  end

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

    def with_schema(*)
      self
    end

    def with_thinking(*)
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
