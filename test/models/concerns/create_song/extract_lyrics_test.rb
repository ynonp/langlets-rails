require "test_helper"

class CreateSongExtractLyricsTest < ActiveSupport::TestCase
  setup do
    @progress = CreateSongProgress.new(
      youtubeurl: "https://example.com/test",
      clip_language: "French",
      translation_language: "English"
    )

    # SRT fixture spanning 0:00 to 1:25 — will split into 3x30s segments
    @rough_srt = <<~SRT
      1
      00:00:05,000 --> 00:00:08,000
      First line of lyrics

      2
      00:00:25,000 --> 00:00:28,500
      Second line here

      3
      00:00:55,000 --> 00:00:58,200
      Third line comes later

      4
      00:01:20,000 --> 00:01:23,000
      Fourth and final line
    SRT
  end

  # ── split_srt_into_segments ──────────────────────────────────────────

  test "split_srt_into_segments splits by time into correct buckets" do
    with_segment_duration(30) do
      segments = @progress.send(:split_srt_into_segments, @rough_srt)

      assert_equal 3, segments.length, "Expected 3 segments, got #{segments.length}"

      # Segment 1: 00:00:00 - 00:00:30
      assert_equal "00:00:00 - 00:00:30", segments[0][:time_range]
      assert_match(/First line/, segments[0][:srt_text])
      assert_match(/Second line/, segments[0][:srt_text])
      assert_no_match(/Third line/, segments[0][:srt_text])

      # Segment 2: 00:00:30 - 00:01:00
      assert_equal "00:00:30 - 00:01:00", segments[1][:time_range]
      assert_match(/Third line/, segments[1][:srt_text])
      assert_no_match(/First line/, segments[1][:srt_text])
      assert_no_match(/Fourth/, segments[1][:srt_text])

      # Segment 3: 00:01:00 - 00:01:30
      assert_equal "00:01:00 - 00:01:30", segments[2][:time_range]
      assert_match(/Fourth/, segments[2][:srt_text])
    end
  end

  test "split_srt_into_segments returns single segment when SRT is shorter than duration" do
    with_segment_duration(300) do # 5 minutes
      segments = @progress.send(:split_srt_into_segments, @rough_srt)

      assert_equal 1, segments.length
      assert_equal "00:00:00 - 00:05:00", segments[0][:time_range]
      assert_match(/First line/, segments[0][:srt_text])
      assert_match(/Fourth/, segments[0][:srt_text])
    end
  end

  test "split_srt_into_segments returns empty array for empty SRT" do
    segments = @progress.send(:split_srt_into_segments, "")
    assert_equal [], segments
  end

  test "split_srt_into_segments handles entry exactly on segment boundary" do
    # Entry at exactly 30.0s should land in segment 2 (30-60), not segment 1 (0-30)
    boundary_srt = <<~SRT
      1
      00:00:30,000 --> 00:00:33,000
      Boundary line
    SRT

    with_segment_duration(30) do
      segments = @progress.send(:split_srt_into_segments, boundary_srt)

      assert_equal 1, segments.length
      assert_equal "00:00:30 - 00:01:00", segments[0][:time_range],
        "Entry at 30.0s should go to the 30-60 bucket, not 0-30"
    end
  end

  test "split_srt_into_segments skips empty buckets" do
    # SRT with entries only at 0:10 and 1:05 — middle bucket should be skipped
    sparse_srt = <<~SRT
      1
      00:00:10,000 --> 00:00:13,000
      Early line

      2
      00:01:05,000 --> 00:01:08,000
      Late line
    SRT

    with_segment_duration(30) do
      segments = @progress.send(:split_srt_into_segments, sparse_srt)

      assert_equal 2, segments.length,
        "Expected 2 non-empty segments, got #{segments.length}"
      assert_equal "00:00:00 - 00:00:30", segments[0][:time_range]
      assert_equal "00:01:00 - 00:01:30", segments[1][:time_range]
    end
  end

  # ── combine_and_renumber_srt ─────────────────────────────────────────

  test "combine_and_renumber_srt produces continuous sequence numbers" do
    seg1 = <<~SRT
      1
      00:00:05,000 --> 00:00:08,000
      Alpha

      2
      00:00:10,000 --> 00:00:13,000
      Beta
    SRT

    seg2 = <<~SRT
      1
      00:00:50,000 --> 00:00:53,000
      Gamma
    SRT

    combined = @progress.send(:combine_and_renumber_srt, [seg1, seg2])

    # Should have 3 entries with sequences 1, 2, 3
    lines = combined.split("\n")
    sequences = lines.select { |l| l.match?(/^\d+$/) }.map(&:to_i)
    assert_equal [1, 2, 3], sequences

    # Verify content preserved
    assert_match(/Alpha/, combined)
    assert_match(/Beta/, combined)
    assert_match(/Gamma/, combined)
  end

  test "combine_and_renumber_srt preserves timestamps and text" do
    seg1 = <<~SRT
      1
      00:01:30,500 --> 00:01:33,200
      Original text
    SRT

    combined = @progress.send(:combine_and_renumber_srt, [seg1])

    assert_match(/00:01:30,500 --> 00:01:33,200/, combined)
    assert_match(/Original text/, combined)
    assert_match(/^1$/, combined.lines.first.strip)
  end

  test "combine_and_renumber_srt handles empty input" do
    combined = @progress.send(:combine_and_renumber_srt, [])
    assert_equal "", combined
  end

  # ── format_srt_segment_time ──────────────────────────────────────────

  test "format_srt_segment_time formats seconds correctly" do
    assert_equal "00:00:00", @progress.send(:format_srt_segment_time, 0)
    assert_equal "00:00:30", @progress.send(:format_srt_segment_time, 30)
    assert_equal "00:01:05", @progress.send(:format_srt_segment_time, 65)
    assert_equal "01:01:01", @progress.send(:format_srt_segment_time, 3661)
  end

  # ── full extract_lyrics integration (stubbed LLM) ────────────────────

  test "extract_lyrics splits SRT and syncs each segment via separate LLM calls" do
    synced_seg1 = <<~SRT
      1
      00:00:04,800 --> 00:00:07,900
      First line synced

      2
      00:00:24,500 --> 00:00:28,200
      Second line synced
    SRT

    synced_seg2 = <<~SRT
      1
      00:00:54,700 --> 00:00:58,000
      Third line synced
    SRT

    synced_seg3 = <<~SRT
      1
      00:01:19,800 --> 00:01:22,700
      Fourth line synced
    SRT

    # Build a fake chat that returns predefined responses in order:
    # call 1 → pass 1 (rough SRT), calls 2-4 → pass 2 segments
    responses = [
      @rough_srt,   # pass 1
      synced_seg1,  # segment 1
      synced_seg2,  # segment 2
      synced_seg3   # segment 3
    ]
    fake_chat = FakeChatQueue.new(responses)

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      with_segment_duration(30) do
        @progress.extract_lyrics
      end
    end

    phrases = @progress.data["phrases"]
    assert_equal 4, phrases.length, "Expected 4 phrases, got #{phrases.length}"

    assert_equal "First line synced", phrases[0]["text_l1"]
    assert_equal "Third line synced", phrases[2]["text_l1"]
    assert_equal "Fourth line synced", phrases[3]["text_l1"]

    # Verify pass 1 was called once and pass 2 called 3 times (one per segment)
    assert_equal 4, fake_chat.call_count
  end

  test "extract_lyrics falls back to pass 1 when pass 2 produces no valid phrases" do
    # Pass 1 returns normal SRT, but all pass 2 segments return garbage
    garbage = "No SRT here, just random text"

    responses = [@rough_srt, garbage, garbage]
    fake_chat = FakeChatQueue.new(responses)

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      with_segment_duration(300) do # 1 segment only
        @progress.extract_lyrics
      end
    end

    phrases = @progress.data["phrases"]
    assert_equal 4, phrases.length, "Fallback should use pass 1 result with 4 phrases"
  end

  test "extract_lyrics handles empty SRT from pass 1 gracefully" do
    responses = ["", ""]
    fake_chat = FakeChatQueue.new(responses)

    stub_renderer_for_extract_lyrics!
    with_fake_chat(fake_chat) do
      @progress.extract_lyrics
    end

    phrases = @progress.data["phrases"]
    assert_equal [], phrases
  end

  private

  # Temporarily override segment duration for isolated method tests.
  def with_segment_duration(seconds, &block)
    @progress.define_singleton_method(:srt_sync_segment_duration) { seconds }
    block.call
  ensure
    @progress.singleton_class.remove_method(:srt_sync_segment_duration) rescue nil
  end

  # Temporarily intercept TracedChat.new to return a fake chat.
  def with_fake_chat(fake_chat, &block)
    original_new = TracedChat.method(:new)
    TracedChat.define_singleton_method(:new) do |**kwargs|
      if kwargs[:span_name].to_s.start_with?("extract_lyrics_")
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
