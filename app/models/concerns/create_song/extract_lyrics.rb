module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

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

      chat1 = TracedChat.new(span_name: "extract_lyrics_pass1", **self.model_params_youtube)
      chat1
        .with_instructions(instructions_pass1)
        .with_temperature(0.2)
        .add_message role: :user, content: user_content

      response1 = chat1.complete
      srt_rough = response1.content.strip

      # --- Pass 2: Sync timestamps to match the actual video ---
      instructions_pass2 = ApplicationController.renderer.render(
        template: "prompts/sync_lyrics_timestamps",
        formats: [ :md ],
        locals: { clip_language: }
      )

      chat2 = TracedChat.new(span_name: "extract_lyrics_pass2", **self.model_params_youtube)
      chat2
        .with_instructions(instructions_pass2)
        .with_temperature(0.2)

      chat2.add_message(role: :user, content: "Here is the SRT file with approximate timestamps that needs correction:\n\n#{srt_rough}")
      chat2.add_message(role: :user, content: user_content)

      response2 = chat2.complete

      phrases = parse_lyrics_response(response2.content.strip)

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
