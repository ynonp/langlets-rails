module CreateSong
  module AddTokenTranslations
    extend ActiveSupport::Concern

    def add_token_translation
      instructions = ApplicationController.renderer.render(
        template: 'prompts/add_token_translations',
        formats: [:md],
        locals: {
          clip_language:,
          translation_language:,
        }
      )
      retry_count = 0
      max_retries = 5

      begin
        chat = TracedChat.new(span_name: "add_token_translations", model: 'gemini-2.5-flash')
        chat.with_instructions(instructions).add_message role: :user, content: full_lyrics

        response = chat.complete
        data["phrases_with_token_translations"] = response.content
        save!

        response
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "AddTokenTranslations attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "AddTokenTranslations failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
    end
  end
end

