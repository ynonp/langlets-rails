module CreateSong
  module AddSimilarSound
    extend ActiveSupport::Concern

    BLOCK_SIZE = 16

    def add_similar_sound
      phrases = data["phrases"].map { |p| p["text_l1"] }
      all_results = []

      phrases.each_slice(BLOCK_SIZE) do |block|
        user_input = block.join("\n")

        instructions = ApplicationController.renderer.render(
          template: 'prompts/add_similar_sound',
          formats: [:md],
          locals: {
            clip_language:,
            user_input:,
          }
        )

        response = process_block_with_retry(instructions)
        all_results << response.content
      end

      data["similar_sounds"] = all_results.join("\n")
      save!
    end

    private

    def process_block_with_retry(instructions)
      retry_count = 0
      max_retries = 2

      begin
        chat = TracedChat.new(span_name: "add_similar_sound", **self.model_params_translate)
        chat
          .with_temperature(0.4)
          .with_instructions(instructions)

        response = chat.complete
        pp response

        Rails.logger.debug "[DEBUG add_similar_sound] response.content class: #{response.content.class}"
        Rails.logger.debug "[DEBUG add_similar_sound] response.content inspect: #{response.content.inspect}"
        Rails.logger.debug "[DEBUG add_similar_sound] response.content blank?: #{response.content.blank?}"

        if response.content.blank?
          Rails.logger.debug "[DEBUG add_similar_sound] CONTENT IS BLANK - raising"
          raise "LLM returned empty response for similar sounds"
        end

        response
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "AddSimilarSound attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "AddSimilarSound failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
    end
  end
end



