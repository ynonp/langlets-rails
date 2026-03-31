module CreateSong
  module Translate
    extend ActiveSupport::Concern

    def build_phrases
      data["phrases"].map { |props| Phrase.new(props) }
    end

    def translate
      instructions = ApplicationController.renderer.render(
        template: 'prompts/add_l2',
        formats: [:md],
        locals: {
          clip_language:,
          translation_language:,
        }
      )
      original_lyrics = data["phrases"].pluck("text_l1")

      user_content = original_lyrics.join("\n")

      retry_count = 0
      max_retries = 5

      begin
        chat = TracedChat.new(span_name: "translate", **self.model_params_translate)
        chat
          .with_instructions(instructions)
          .with_temperature(0.2)
          .add_message role: :user, content: user_content

        response = chat.complete

        translation_lines = response.content.lines.map(&:chomp).reject(&:blank?)
        phrases = data["phrases"]
        raise "Bad translation, line count doesnt match #{translation_lines.size} != #{phrases.size}" if translation_lines.size != phrases.size

        translation_lines.zip(phrases) do |text, phrase|
          phrase["text_l2"] = text
        end

        save!
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "Translate attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "Translate failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
    end

  end
end

