module CreateSong
  module AddSimilarSound
    extend ActiveSupport::Concern

    def add_similar_sound
      user_input = data["phrases"].map {|p| p["text_l1"] }.join("\n")

      instructions = ApplicationController.renderer.render(
        template: 'prompts/add_similar_sound',
        formats: [:md],
        locals: {
          clip_language:,
          user_input:,
        }
      )
      retry_count = 0
      max_retries = 5

      begin
        chat = TracedChat.new(span_name: "add_similar_sound", model: 'gemini-3-flash-preview', assume_model_exists: true, provider: :gemini)
        chat
          .with_temperature(0.4)
          .with_instructions(instructions)

        response = chat.complete
        data["similar_sounds"] = response.content
        save!

        response
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "AddSimilarSound attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "AddSimilarSound failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
    end
  end
end



