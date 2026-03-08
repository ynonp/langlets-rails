module CreateSong
  module AddFlashcards
    extend ActiveSupport::Concern

    def add_flashcards
      instructions = ApplicationController.renderer.render(
        template: 'prompts/add_flashcards',
        formats: [:md],
        locals: {
          clip_language:,
        }
      )
      retry_count = 0
      max_retries = 5

      begin
        chat = TracedChat.new(span_name: "add_lessons", **self.model_params_quick)
        user_content = data["phrases"].map {|p| "#{p["timestamp"]} #{p["text_l1"]}" }.join("\n")
        chat
          .with_temperature(0.4)
          .with_instructions(instructions)
          .add_message role: :user, content: user_content
        response = chat.complete
        data["lessons"] = response.content
        save!

        response
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "AddLessons attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "AddLessons failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
    end
  end
end



