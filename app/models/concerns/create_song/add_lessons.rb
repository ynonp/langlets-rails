module CreateSong
  module AddLessons
    extend ActiveSupport::Concern

    class AddLessonsOutput < RubyLLM::Schema
      array :lessons do
        object do
          number :order, description: "Lesson Order"
          string :title, description: "Lesson title"
          string :description, description: "Lesson short description"
          array :phrases, description: "Phrases for this lesson" do
            object do
              string :id
              string :text, description: "phrase text"
              string :timestamp, description: "phrase timestamp (format MM:SS)"
            end
          end
        end
      end
    end

    def add_lessons
      Langsmith.trace("add_lessons", attributes: {
        "gen_ai.request.model" => "gemini-2.5-flash-preview-05-20",
        "gen_ai.system" => "Gemini"
      }) do |tracer|
        phrases_for_llm = data["phrases"].map do |phrase|
          {
            "phrase_id" => phrase["id"],
            "text_l1" => phrase["text_l1"],
            "timestamp" => phrase["timestamp"],
          }
        end
        template_path = Rails.root.join('prompts', 'add_lessons.md.erb')
        template = File.read(template_path)

        instructions = ApplicationController.renderer.render(
          inline: template,
          locals: {
            clip_language:,
            translation_language:,
          }
        )
        chat = RubyLLM.chat(model: 'gemini-2.5-flash-preview-05-20')
        user_content = JSON.pretty_generate(phrases_for_llm)
        chat
          .with_temperature(0.4)
          .with_instructions(instructions)
          .with_schema(AddLessonsOutput)
          .add_message role: :user, content: user_content
        response = chat.complete
        tracer.trace(response)
        data["lessons"] = response.content["lessons"]
        save!

        response
      end
    end
  end
end


