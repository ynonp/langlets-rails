module CreateSong
  module RateLessons
    extend ActiveSupport::Concern

    MODEL_PARAMS = {
      model: 'deepseek-v4-pro:cloud',
      provider: :ollama,
      assume_model_exists: true
    }.freeze

    # Lessons scoring at or below this are considered low-value and can be filtered
    # out of the generated course (see CourseBuilder::BuildSong).
    LOW_VALUE_SCORE = 2

    def rate_lessons
      return if data["lessons"].blank?

      instructions = ApplicationController.renderer.render(
        template: "prompts/rate_lessons",
        formats: [ :md ],
        locals: {
          clip_language:,
          translation_language:
        }
      )

      retry_count = 0
      max_retries = 5

      begin
        chat = TracedChat.new(span_name: "rate_lessons", **MODEL_PARAMS)

        chat
          .with_temperature(0.2)
          .with_instructions(instructions)
          .add_message role: :user, content: data["lessons"]

        response = chat.complete
        raise "LLM returned nil" if response.content.nil?

        ratings = parse_ratings(response.content)
        raise "No ratings parsed" if ratings.empty?

        data["lesson_ratings"] = ratings
        save!

        response
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "RateLessons attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "RateLessons failed after #{max_retries} attempts: #{e.message}"
          raise e
        end
      end
    end

    def lessons_rated?
      data["lesson_ratings"].present?
    end

    private

    # The LLM is asked for a bare JSON array, but tolerate markdown fences and any
    # surrounding prose by extracting the first [...] block.
    def parse_ratings(content)
      json = content[/\[.*\]/m]
      return [] if json.nil?

      parsed = JSON.parse(json)
      return [] unless parsed.is_a?(Array)

      parsed.map do |row|
        {
          "index"  => row["index"],
          "title"  => row["title"].to_s.strip,
          "score"  => row["score"].to_i,
          "reason" => row["reason"].to_s.strip
        }
      end
    rescue JSON::ParserError => e
      Rails.logger.warn "RateLessons could not parse JSON: #{e.message}"
      []
    end
  end
end
