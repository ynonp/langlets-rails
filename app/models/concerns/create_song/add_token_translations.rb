module CreateSong
  module AddTokenTranslations
    extend ActiveSupport::Concern

    class AddTokenTranslationOutput < RubyLLM::Schema
      array :phrases, description: "List of phrases with their token translations" do
        object do
          string :phrase_id, description: "Unique identifier for the phrase"
          string :clip_text, description: "Original text in clip language"
          string :translation_text, description: "Translated text"
          array :translations, description: "List of token alignments" do 
            object do
              array :translation_indices, of: :number, description: "Indices of tokens in the translation language"
              array :clip_indices, of: :number, description: "Indices of tokens in the clip language"
              array :translation_tokens, of: :string, description: "Actual tokens in the translation language"
              array :clip_tokens, of: :string, description: "Actual tokens in the clip language"
            end
          end
        end
      end
    end

    def add_token_translation
      Langsmith.trace("add_token_translations", attributes: {
        "gen_ai.request.model" => "gemini-2.5-pro",
        "gen_ai.system" => "Google"
      }) do |tracer|
        phrases_for_llm = data["phrases"].map do |phrase|
          {
            "phrase_id" => phrase["id"],
            "clip_text" => phrase["text_l1"],
            "translation_text" => phrase["text_l2"],
            "clip_tokens" => phrase["text_l1"].tokenize.map(&:to_s),
            "translation_tokens" => phrase["text_l2"].tokenize.map(&:to_s)
          }
        end
        template_path = Rails.root.join('prompts', 'add_token_translations.md.erb')
        template = File.read(template_path)

        instructions = ApplicationController.renderer.render(
          inline: template,
          locals: {
            clip_language:,
            translation_language:,
          }
        )
        chat = RubyLLM.chat(model: 'gemini-2.5-pro')
        user_content = JSON.pretty_generate(phrases_for_llm)
        retry_count = 0
        max_retries = 5
        
        begin
          chat.with_instructions(instructions).with_schema(AddTokenTranslationOutput).add_message role: :user, content: user_content
          response = chat.complete
          tracer.trace(response)
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
end

