module CreateSong
  module ExtractLyrics
    extend ActiveSupport::Concern

    class ExtractLyricsOutput < RubyLLM::Schema
      array :phrases do
        object do
          string :id, description: "unique id of the phrase"
          string :text_l1, description: "phrase original text"
          string :timestamp, description: "timestamp in the audio, format mm:ss"
        end
      end
      string :youtube_url, description: "Validation - The youtube URL you parsed"
      string :total_video_duration, description: "Validation - The video duration you parsed"
    end

    def extract_lyrics
      Langsmith.trace("extract_lyrics", attributes: {
         "gen_ai.request.model" => "gemini-2.5-pro",
         "gen_ai.system" => "Gemini"
      }) do |tracer|
        template_path = Rails.root.join('prompts', 'extract_phrases_from_youtube_url.md.erb')
        template = File.read(template_path)

        instructions = ApplicationController.renderer.render(
          inline: template,
          locals: {
            clip_language:,
          }
        )

        user_content = Llm::YoutubeUrlContent.new(youtubeurl)
        
        # Set the prompt content for tracing before making the API call
        tracer.set_prompt_content(instructions, user_content)

        chat = RubyLLM.chat(model: 'gemini-2.5-pro')
        chat.with_instructions(instructions).with_schema(ExtractLyricsOutput).add_message role: :user, content: user_content
        response = chat.complete
        tracer.trace(response)

        self.data ||= {}
        self.data["phrases"] = response.content["phrases"]

        save!
      end
    end

  end
end
