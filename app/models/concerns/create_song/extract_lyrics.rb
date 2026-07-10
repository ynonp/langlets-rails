module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

    MODEL_PARAMS = {
      model: 'gemini-3.5-flash',
      provider: :gemini,
      assume_model_exists: true
    }.freeze

    # Minimum fraction of the video (by the last transcribed timestamp vs. the
    # model-reported total length) that must be covered for the step to succeed.
    # Below this we assume the transcription bailed out early -- the model stopped
    # making progress, hit MAX_CONTINUATION_TURNS mid-video, etc. -- and fail the
    # pipeline rather than ship a song that's missing most of its lyrics.
    MIN_COVERAGE_RATIO = 0.5

    # Raised when the transcription covers less than MIN_COVERAGE_RATIO of the
    # video, so the pipeline fails loudly instead of persisting a truncated song.
    class IncompleteTranscriptionError < StandardError; end

    def full_lyrics
      data["phrases"].pluck("text_l1").join("\n")
    end

    # Max lines the model returns per call (see the schema / prompt). Long videos
    # exceed a single response's output-token budget, so we page through them.
    MAX_CONTINUATION_TURNS = 20

    # Transcribes the video into word-timed phrases. Each LLM call returns JSON
    # with line- and word-level timestamps (see WordTimingParser) for up to 30
    # lines plus a "has_more" flag. When the model reports there is more content,
    # we keep the same chat (so the video stays in context) and ask it to
    # continue from the last line we received, accumulating phrases until the
    # model reaches the end of the video -- or stops making forward progress.
    # We parse into data["phrases"], each carrying a "words" array. Every word
    # also gets its l1_start_index / l1_end_index (character span within text_l1)
    # computed here so downstream steps can build tokens without re-searching.
    def extract_lyrics
      user_content = Llm::YoutubeUrlContent.new(youtubeurl)

      instructions = ApplicationController.renderer.render(
        template: "prompts/extract_phrases_from_youtube_url",
        formats: [ :md ],
        locals: { clip_language: }
      )

      chat = TracedChat.new(span_name: "extract_lyrics", **MODEL_PARAMS)
      chat
        .with_instructions(instructions)
        .with_schema(LyricsTranscriptionSchema)
        # gemini-3.5-flash is a reasoning model and, left unbounded, spends its
        # entire ~64k output-token budget "thinking" -- the JSON then truncates
        # mid-line and fails to parse. Transcription is mechanical, so cap the
        # reasoning to thinkingLevel:low (≈800 thinking tokens vs ≈63k), which
        # leaves the budget for the actual output. (thinkingBudget is ignored by
        # the Gemini 3 family; only the effort/level control works here.)
        .with_thinking(effort: :medium)
        .with_temperature(0.2)
        .add_message role: :user, content: user_content

      phrases = []
      video_length = nil

      (MAX_CONTINUATION_TURNS + 1).times do
        # With a schema, response.content is the parsed Hash
        # ({ "lines" => [...], "has_more" => bool, "video_length" => srt }).
        response = chat.complete

        # The model reports the total video length on every turn; keep the latest
        # non-blank value so we can measure how much of the video we covered.
        video_length = response.content["video_length"] if response.content["video_length"].present?

        previous_count = phrases.length
        phrases = merge_phrases(phrases, WordTimingParser.parse(response.content))

        # Stop when the model says it reached the end of the video, or when a
        # continuation turn added nothing new (no forward progress -- e.g. the
        # model just re-emitted lines we already have).
        break unless response.content["has_more"]
        break if phrases.length == previous_count

        chat.add_message role: :user, content: continuation_prompt(phrases.last)
      end

      self.data ||= {}
      self.data["phrases"] = phrases

      save!

      ensure_video_coverage!(phrases, video_length)
    end

    private

    # Guard against a transcription that stopped well before the end of the
    # video. We compare the last transcribed timestamp against the total video
    # length the model reported and fail the pipeline if we covered less than
    # MIN_COVERAGE_RATIO of it. A blank/unparseable length means we can't judge
    # coverage, so we let it through rather than fail on missing metadata.
    def ensure_video_coverage!(phrases, video_length)
      total_seconds = srt_to_seconds(video_length)
      return if total_seconds.nil? || total_seconds <= 0

      covered_seconds = phrases.filter_map { |phrase| Phrase.timestamp_to_seconds(phrase["timestamp_end"]) }.max || 0.0
      ratio = covered_seconds / total_seconds
      return if ratio >= MIN_COVERAGE_RATIO

      raise IncompleteTranscriptionError,
        "Transcription only covered #{(ratio * 100).round}% of the video " \
        "(#{covered_seconds.round}s of #{total_seconds.round}s); " \
        "at least #{(MIN_COVERAGE_RATIO * 100).round}% is required."
    end

    # Parse the model's SRT video-length string ("HH:MM:SS,mmm") into float
    # seconds. SRT uses a comma decimal separator, so normalize it to a dot
    # before delegating to the shared HasTimestamp parser. Returns nil for
    # blank/malformed input.
    def srt_to_seconds(srt)
      return nil if srt.blank?

      HasTimestamp.timestamp_to_seconds(srt.to_s.strip.tr(",", "."))
    end

    # Append a fresh batch of parsed phrases onto the ones gathered so far,
    # dropping any lines the model repeats (same timestamp + text) and renumbering
    # the "id" of each phrase so ids stay unique and sequential across batches.
    def merge_phrases(existing, incoming)
      seen = Set.new
      (existing + drop_backwards_phrases(existing, incoming))
        .reject { |phrase| !seen.add?([ phrase["timestamp"], phrase["text_l1"] ]) }
        .each_with_index
        .map { |phrase, idx| phrase.merge("id" => "phrase_#{idx + 1}") }
    end

    # Discard continuation lines that start before the latest line we already
    # accepted. The model is asked to resume *after* the last line, so an earlier
    # timestamp means it went backwards -- a repeat or a hallucinated line (e.g. a
    # chorus re-emitted with a jittered timestamp) -- which must not slip past the
    # exact-match dedup in merge_phrases. Lines that start at or after the cutoff
    # are kept (a legitimately repeated later chorus keeps its distinct timestamp).
    def drop_backwards_phrases(existing, incoming)
      return incoming if existing.empty?

      cutoff = existing.map { |phrase| Phrase.timestamp_to_seconds(phrase["timestamp"]) }.max
      incoming.select { |phrase| Phrase.timestamp_to_seconds(phrase["timestamp"]) >= cutoff }
    end

    # Message that asks the model to resume transcription right after the last
    # line we received, so the next call returns the following batch.
    def continuation_prompt(last_phrase)
      <<~MSG
        Continue transcribing the SAME video from immediately after this line, and
        return at most 30 more lines. Do not repeat any line you already returned,
        and every line you return must start at or after #{last_phrase["timestamp_end"]}
        -- never return a line with an earlier timestamp.

        Last line returned:
        - timestamp: #{last_phrase["timestamp"]} - #{last_phrase["timestamp_end"]}
        - text: #{last_phrase["text_l1"]}

        Set has_more to true if content still remains after your new lines, or false
        once you have reached the end of the video.
      MSG
    end
  end
end
