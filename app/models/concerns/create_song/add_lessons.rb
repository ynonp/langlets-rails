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
      retry_count = 0
      max_retries = 5

      begin
        chat = RubyLLM.chat(model: 'gemini-2.5-flash')
        user_content = JSON.pretty_generate(phrases_for_llm)
        chat
          .with_temperature(0.4)
          .with_instructions(instructions)
          .with_schema(AddLessonsOutput)
          .add_message role: :user, content: user_content
        response = chat.complete
        data["lessons"] = response.content["lessons"]
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


