require "async/semaphore"

module CreateSong
  module AddTokenTranslations
    extend ActiveSupport::Concern

    def add_token_translation
      blocks_per_iteration = 1
      max_concurrency = 1
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

      blocks = lyrics_with_translations.lines.each_slice(blocks_per_iteration).to_a

      semaphore = Async::Semaphore.new(max_concurrency)

      results = Async do
        tasks = blocks.each_with_index.map do |block, index|
          Async do
            semaphore.acquire do
              content = fetch_translation(instructions, block, max_retries)
              [index, content]
            end
          end
        end

        tasks.map(&:wait).sort_by(&:first).map(&:last)
      end.result

      data["phrases_with_token_translations"] = results.join("\n\n")
      save!
    end

    private

    def fetch_translation(instructions, block, max_retries)
      retry_count = 0

      loop do
        validate_input_no_brackets!(block)

        chat = TracedChat.new(span_name: "add_token_translations", **self.model_params_smart)
        chat
          .with_instructions(instructions)
          .add_message role: :user, content: block.join

        response = chat.complete
        pp response

        content = strip_model_header(response.content.strip, block.first)
        raise "Output blocks mismatch" if content.strip.scan(/\n\s*\n/).count != (block.size - 1)

        validate_one_token_per_line!(content)

        return content.strip
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

    def lyrics_with_translations
      lyrics = data["phrases"].pluck("text_l1")
      translations = data["phrases"].pluck("text_l2")
      lyrics.zip(translations).map { |l, t| "#{l} => #{t}" }.join("\n")
    end

    def validate_input_no_brackets!(block)
      block.each do |line|
        if line.include?("[") || line.include?("]")
          raise "Input line contains square brackets: #{line.strip}"
        end
      end
    end

    def validate_one_token_per_line!(content)
      content_blocks = content.strip.split(/\n\s*\n/)
      content_blocks.each do |output_block|
        source_side = output_block.split("=>", 2).first
        match_count = source_side.scan(/\[.*?\]/).count
        if match_count != 1
          raise "Expected exactly 1 [...] on source side, got #{match_count} in: #{output_block.strip}"
        end
      end
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
