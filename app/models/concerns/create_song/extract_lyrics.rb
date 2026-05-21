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

    # Normalizes 2-part SRT timestamps (MM:SS,mmm) to 3-part (00:MM:SS,mmm)
    # Only matches lines where BOTH timestamps are 2-part; leaves 3-part lines untouched
    SRT_NORMALIZE_REGEX = /(\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2},\d{3})/

    def parse_lyrics_response(response_text)
      normalized = response_text.gsub(SRT_NORMALIZE_REGEX, '00:\1 --> 00:\2')

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
