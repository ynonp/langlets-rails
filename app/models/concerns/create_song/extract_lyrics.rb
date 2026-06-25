module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

    MODEL_PARAMS = {
      model: 'gemini-3.5-flash',
      provider: :gemini,
      assume_model_exists: true
    }.freeze

    def full_lyrics
      data["phrases"].pluck("text_l1").join("\n")
    end

    def extract_lyrics
      user_content = Llm::YoutubeUrlContent.new(youtubeurl)

      # --- Pass 1: Extract lyrics (SRT with approximate timestamps) ---
      instructions_pass1 = ApplicationController.renderer.render(
        template: "prompts/extract_phrases_from_youtube_url",
        formats: [ :md ],
        locals: { clip_language: }
      )

      chat1 = TracedChat.new(span_name: "extract_lyrics_pass1", **MODEL_PARAMS)
      chat1
        .with_instructions(instructions_pass1)
        .with_temperature(0.2)
        .add_message role: :user, content: user_content

      response1 = chat1.complete
      srt_rough = response1.content.strip

      # --- Pass 2: Sync timestamps per segment (avoids LLM choking on large SRT) ---
      instructions_pass2 = ApplicationController.renderer.render(
        template: "prompts/sync_lyrics_timestamps",
        formats: [ :md ],
        locals: { clip_language: }
      )

      segments = split_srt_into_segments(srt_rough)

      if segments.empty?
        Rails.logger.warn "No SRT segments to sync; falling back to pass 1 result"
        phrases = parse_lyrics_response(srt_rough)
      else
        synced_segments = segments.map.with_index(1) do |segment, i|
          sync_srt_segment(i, segments.length, segment, user_content, instructions_pass2)
        end

        combined_srt = combine_and_renumber_srt(synced_segments)
        phrases = parse_lyrics_response(combined_srt)
      end

      # Fallback: if pass 2 produced no phrases, use pass 1 result
      if phrases.empty?
        Rails.logger.warn "Pass 2 timestamp sync produced no phrases; falling back to pass 1 result"
        phrases = parse_lyrics_response(srt_rough)
      end

      self.data ||= {}
      self.data["phrases"] = phrases

      save!
    end

    private

    # Duration of each SRT sync segment in seconds (default: 8 minutes).
    # Overridable in tests for smaller segment sizes.
    def srt_sync_segment_duration
      8 * 60
    end

    # Splits an SRT string into time-based segments for granular LLM sync.
    # Returns an array of { srt_text:, time_range: } hashes.
    def split_srt_into_segments(srt_text)
      normalized = normalize_srt_timestamps(srt_text)
      file = SRT::File.parse(normalized)

      return [] if file.lines.empty?

      segment_duration = srt_sync_segment_duration
      max_time = file.lines.map(&:end_time).max
      segments = []

      bucket_start = 0.0
      while bucket_start < max_time
        bucket_end = bucket_start + segment_duration

        bucket_lines = file.lines.select do |line|
          line.start_time >= bucket_start && line.start_time < bucket_end
        end

        if bucket_lines.any?
          srt_text = bucket_lines.map { |l| "#{l}\n" }.join
          time_from = format_srt_segment_time(bucket_start)
          time_to   = format_srt_segment_time(bucket_end)
          segments << {
            srt_text: srt_text,
            time_range: "#{time_from} - #{time_to}"
          }
        end

        bucket_start = bucket_end
      end

      segments
    end

    # Runs a single LLM call to sync one SRT segment's timestamps against the video.
    def sync_srt_segment(segment_number, total_segments, segment, user_content, instructions)
      chat = TracedChat.new(
        span_name: "extract_lyrics_pass2_segment_#{segment_number}",
        **MODEL_PARAMS
      )
      chat
        .with_instructions(instructions)
        .with_temperature(0.2)

      chat.add_message(
        role: :user,
        content: "Segment #{segment_number} of #{total_segments} (#{segment[:time_range]}):\n\n#{segment[:srt_text]}"
      )
      chat.add_message(role: :user, content: user_content)

      chat.complete.content.strip
    end

    # Concatenates multiple synced SRT segments and renumbers sequences from 1.
    def combine_and_renumber_srt(synced_texts)
      all_lines = []
      sequence = 1

      synced_texts.each do |srt_text|
        normalized = normalize_srt_timestamps(srt_text)
        file = SRT::File.parse(normalized)

        file.lines.each do |line|
          # Skip lines that failed to parse (e.g. garbage LLM output)
          next if line.error || line.start_time.nil? || line.end_time.nil?

          line.sequence = sequence
          all_lines << line.to_s
          sequence += 1
        end
      end

      return "" if all_lines.empty?

      all_lines.join("\n") + "\n"
    end

    # Formats seconds as HH:MM:SS for human-readable segment time ranges.
    def format_srt_segment_time(seconds)
      h = (seconds / 3600).floor
      m = ((seconds % 3600) / 60).floor
      s = (seconds % 60).floor
      format("%02d:%02d:%02d", h, m, s)
    end

    def parse_response_metadata(response_text)
      lines = response_text.split("\n")
      video_accessed = nil
      confidence = nil

      # Check first two lines for metadata
      lines.first(2).each do |line|
        line = line.strip
        if line.match(/^VIDEO_ACCESSED:\s*(YES|NO)$/i)
          video_accessed = $1.upcase == "YES"
        elsif line.match(/^CONFIDENCE:\s*(\d+)$/i)
          confidence = $1.to_i
        end
      end

      [ video_accessed, confidence ]
    end

    # Normalizes SRT timestamps to standard 3-part format (HH:MM:SS,mmm).
    # The model is asked to output HH:MM:SS,mmm but sometimes still outputs MM:SS,mmm.
    # This ensures both formats end up as valid 3-part before handing to SRT::File.parse.
    def normalize_srt_timestamps(text)
      # Strip any existing "00:" hour prefix from 3-part timestamps first,
      # then normalize all remaining 2-part timestamps to 3-part.
      text = text.gsub(/\b00:(\d{2}:\d{2},\d{3})\b/, '\1')
      text.gsub(/\b(\d{2}:\d{2},\d{3})\b/, '00:\1')
    end

    def parse_lyrics_response(response_text)
      normalized = normalize_srt_timestamps(response_text)
      file = SRT::File.parse(normalized)

      file.lines.map do |line|
        {
          "id" => "phrase_#{line.sequence}",
          "text_l1" => line.text.join(" ").gsub("[", "(").gsub("]", ")"),
          "timestamp" => Phrase.to_string_timestamp(line.start_time),
          "timestamp_end" => Phrase.to_string_timestamp(line.end_time)
        }
      end
      .reject { |phrase| phrase["text_l1"].blank? }
    end
  end
end
