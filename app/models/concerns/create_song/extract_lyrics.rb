module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

    def extract_lyrics
      Langsmith.trace("extract_lyrics", attributes: {
         "gen_ai.request.model" => "gemini-2.5-pro",
         "gen_ai.system" => "Gemini"
      }) do |tracer|
        template_path = Rails.root.join('prompts', 'extract_phrases_from_youtube_url.md.erb')
        template = File.read(template_path)

        instructions = ApplicationController.renderer.render(
          inline: template,
          locals: {
            clip_language:,
          }
        )

        user_content = Llm::YoutubeUrlContent.new(youtubeurl)
        
        # Set the prompt content for tracing before making the API call
        tracer.set_prompt_content(instructions, user_content)

        retry_count = 0
        max_retries = 5
        
        begin
          chat = RubyLLM.chat(model: 'gemini-2.5-pro')
          chat.with_instructions(instructions).add_message role: :user, content: user_content
          response = chat.complete
          tracer.trace(response)

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
    end

    private

    def parse_lyrics_response(response_text)
      phrases = []
      
      response_text.split("\n").each_with_index do |line, index|
        line = line.strip
        next if line.empty?
        
        # Match format: [timestamp] [phrase] or timestamp phrase
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
