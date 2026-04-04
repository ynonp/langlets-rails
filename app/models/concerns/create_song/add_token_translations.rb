module CreateSong
  module AddTokenTranslations
    extend ActiveSupport::Concern

    def add_token_translation
      blocks_per_iteration = 1
      instructions = ApplicationController.renderer.render(
        template: "prompts/add_token_translations",
        formats: [ :md ],
        locals: {
          clip_language:,
          translation_language:,
          expected_block_count: blocks_per_iteration,
        }
      )
      max_retries = 2
      data["phrases_with_token_translations"] = ""

      lyrics_with_translations.lines.each_slice(blocks_per_iteration) do |block|
        retry_count = 0

        begin
          chat = TracedChat.new(span_name: "add_token_translations", **self.model_params_quick)
          chat
            .with_instructions(instructions)
            .add_message role: :user, content: block.join

          response = chat.complete

          content = strip_model_header(response.content.strip, block.first)
          raise "Output blocks mismatch" if content.strip.scan(/\n\s*\n/).count != (blocks_per_iteration - 1)
          data["phrases_with_token_translations"] += content.strip + "\n\n"
          save!

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

    private

    def lyrics_with_translations
      lyrics = data["phrases"].pluck("text_l1")
      translations = data["phrases"].pluck("text_l2")
      lyrics.zip(translations).map { |l, t| "#{l} => #{t}" }.join("\n")
    end

    def strip_model_header(content, first_input_line)
      first_input_without_brackets = first_input_line.strip.gsub(/\[|\]/, "").sub(/\s*#.*$/, "")

      content_lines = content.lines
      first_valid_line_index = content_lines.find_index do |line|
        stripped = line.strip.gsub(/\[|\]/, "").sub(/\s*#.*$/, "")
        stripped == first_input_without_brackets
      end

      if first_valid_line_index
        content_lines[first_valid_line_index..].join
      else
        content
      end
    end
  end
end
