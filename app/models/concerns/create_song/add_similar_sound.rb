module CreateSong
  module AddSimilarSound
    extend ActiveSupport::Concern

    def add_similar_sound
      Langsmith.trace("add_similar_sound", attributes: {
        "gen_ai.request.model" => "gemini-2.5-flash",
        "gen_ai.system" => "Gemini"
      }) do |tracer|
        template_path = Rails.root.join('prompts', 'add_similar_sound.md.erb')
        template = File.read(template_path)
        user_input = data["phrases"].map {|p| p["text_l1"] }.join("\n")

        instructions = ApplicationController.renderer.render(
          inline: template,
          locals: {
            clip_language:,
            user_input:,
          }
        )
        chat = RubyLLM.chat(model: 'gemini-2.5-flash')
        chat
          .with_temperature(0.4)
          .with_instructions(instructions)

        response = chat.complete
        tracer.trace(response)
        data["similar_sounds"] = response.content
        save!

        response
      end
    end
  end
end



