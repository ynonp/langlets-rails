module CreateSong
  module AddHebrewScript
    extend ActiveSupport::Concern

    def add_hebrew_script
      Langsmith.trace("add_hebrew_script", attributes: {
        "gen_ai.request.model" => "gemini-2.5-flash",
        "gen_ai.system" => "Gemini"
      }) do |tracer|
        template_path = Rails.root.join('prompts', 'add_hebrew_script.md.erb')
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
        data["hebrew_script"] = response.content
        save!

        response
      end
    end
  end
end




