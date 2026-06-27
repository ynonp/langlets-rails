require "async/semaphore"

module CreateSong
  module AddTokenTranslations
    extend ActiveSupport::Concern

    MODEL_PARAMS = {
      model: 'deepseek-v4-pro:cloud',
      provider: :openai,
      assume_model_exists: true
    }.freeze

    # Translates each word of every phrase into the target language. Unlike the
    # old alignment step, this does NOT compute L2 character ranges -- it simply
    # produces one translation per word (with the full phrase for context). The
    # word translations + their timestamps later become karaoke-capable
    # TokenTranslation records (see Phrase#build_word_tokens).
    def add_token_translation
      max_concurrency = 4
      max_retries = 2

      instructions = ApplicationController.renderer.render(
        template: "prompts/translate_words",
        formats: [ :md ],
        locals: {
          clip_language:,
          translation_language:,
        }
      )

      phrases = data["phrases"]
      semaphore = Async::Semaphore.new(max_concurrency)

      results = Async do
        tasks = phrases.each_with_index.map do |phrase, index|
          Async do
            semaphore.acquire do
              [ index, translate_phrase_words(instructions, phrase, max_retries) ]
            end
          end
        end

        tasks.map(&:wait).sort_by(&:first).map(&:last)
      end.result

      results.each_with_index do |translations, index|
        words = data["phrases"][index]["words"]
        next if words.blank?

        words.each_with_index do |word, w_index|
          word["translation"] = translations[w_index]
        end
      end

      save!
    end

    private

    def translate_phrase_words(instructions, phrase, max_retries)
      words = Array(phrase["words"]).map { |w| w["text"] }
      return [] if words.empty?

      retry_count = 0

      loop do
        chat = TracedChat.new(span_name: "add_token_translations", **MODEL_PARAMS)
        chat
          .with_instructions(instructions)
          .add_message role: :user, content: "Phrase: #{phrase["text_l1"]}\nWords:\n#{words.join("\n")}"

        response = chat.complete

        return parse_word_translations(response.content.strip, words)
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

    # Expects one "word => translation" line per input word, in order. Ignores any
    # preamble lines that don't contain "=>", then validates the count matches.
    def parse_word_translations(content, words)
      translations = content.lines
        .map(&:strip)
        .reject(&:blank?)
        .select { |line| line.include?("=>") }
        .map { |line| line.split("=>", 2).last.to_s.strip }

      if translations.size != words.size
        raise "Word translation count mismatch: got #{translations.size}, expected #{words.size}"
      end

      translations
    end
  end
end
