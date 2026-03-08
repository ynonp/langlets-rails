module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

    def full_lyrics
      data["phrases"].pluck("text_l1").join("\n")
    end

    def extract_lyrics
      instructions = ApplicationController.renderer.render(
        template: 'prompts/extract_phrases_from_youtube_url',
        formats: [:md],
        locals: {
          clip_language:,
        }
      )

      user_content = Llm::YoutubeUrlContent.new(youtubeurl)

      retry_count = 0
      max_retries = 5

      begin
        chat = TracedChat.new(span_name: "extract_lyrics", **self.model_params_youtube)
        chat
          .with_instructions(instructions)
          .with_temperature(0.2)
          .add_message role: :user, content: user_content
        response = chat.complete

        # Parse metadata from beginning of response
        video_accessed, confidence = parse_response_metadata(response.content)

        # Verify video was accessed
        unless video_accessed
          raise "Model could not access video - aborting extraction"
        end

        # Log warning for low confidence
        if confidence && confidence < 70
          Rails.logger.warn "ExtractLyrics low confidence score: #{confidence} - proceeding with caution"
        end

        phrases = parse_lyrics_response(response.content)

        self.data ||= {}
        self.data["phrases"] = phrases

        save!
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "ExtractLyrics attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "ExtractLyrics failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
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

      [video_accessed, confidence]
    end

    def parse_lyrics_response(response_text)
      phrases = []

      # Skip first 2 lines (metadata) and parse the rest
      response_text.split("\n").drop(2).each_with_index do |line, index|
        line = line.strip
        next if line.empty?

        # Match format: [timestamp] [phrase]
        if line.match(/^(\d{2}:\d{2})\s+(.+)$/)
          timestamp = $1
          text = $2

          phrases << {
            "id" => "phrase_#{index + 1}",
            "text_l1" => text,
            "timestamp" => timestamp
          }
        end
      end

      phrases
    end
  end
end
