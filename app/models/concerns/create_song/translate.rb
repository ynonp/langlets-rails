module CreateSong
  module Translate
    extend ActiveSupport::Concern

    def translate
      Langsmith.trace("translate", attributes: {
        "gen_ai.request.model" => "z-ai/glm-4.5",
        "gen_ai.system" => "z.ai"
      }) do |tracer|
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
        
        # Set the prompt content for tracing before making the API call
        tracer.set_prompt_content(instructions, user_content)

        chat = RubyLLM.chat(model: 'z-ai/glm-4.5')
        chat.with_instructions(instructions).add_message role: :user, content: user_content
        response = chat.complete
        tracer.trace(response)

        response.content.lines.map(&:chomp).reject(&:blank?).each_with_index.map do |l2, index|
          data["phrases"][index]["text_l2"] = l2
        end

        save!
      end
    end

  end
end

