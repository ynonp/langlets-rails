module CreateSong
  module Translate
    extend ActiveSupport::Concern

    def translate
      template_path = Rails.root.join('prompts', 'add_l2.md.erb')
      template = File.read(template_path)

      instructions = ApplicationController.renderer.render(
        inline: template,
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
        chat = RubyLLM.traced_chat(span_name: "translate", model: 'gemini-2.5-flash')
        chat.with_instructions(instructions).add_message role: :user, content: user_content
        response = chat.complete

        response.content.lines.map(&:chomp).reject(&:blank?).each_with_index.map do |l2, index|
          data["phrases"][index]["text_l2"] = l2
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

