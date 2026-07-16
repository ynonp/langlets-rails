require "async/semaphore"

module CreateSong
  module AddTokenTranslations
    extend ActiveSupport::Concern

    MODEL_PARAMS = {
      model: 'deepseek-v4-pro:cloud',
      provider: :ollama,
      assume_model_exists: true
    }.freeze

    # Words per LLM call. We translate every word of every phrase, so for a long
    # song this is hundreds of words; batching keeps each request small enough to
    # stay accurate while still cutting the number of round-trips dramatically.
    WORDS_PER_CHUNK = 200

    # Translates each word of every phrase into the target language. Every word
    # across all phrases is collected, grouped into chunks of WORDS_PER_CHUNK and
    # sent to the LLM with the full phrase as context (the word being translated is
    # marked with *asterisks*). The resulting per-word translations + their
    # timestamps later become karaoke-capable TokenTranslation records (see
    # WordTokenBuilder#build_word_tokens).
    def add_token_translation
      max_concurrency = 4
      max_retries = 2

      # Collects per-chunk failures (error + the raw LLM response that produced
      # it) while the async tasks run. We can't safely write to the DB from
      # inside the reactor, so we accumulate here and persist in the rescue.
      @translation_failures = []

      instructions = ApplicationController.renderer.render(
        template: "prompts/add_token_translations",
        formats: [ :md ],
        locals: {
          clip_language:,
          translation_language:,
        }
      )

      # Flat list of every word with a back-reference to its phrase/word slot, so
      # we can scatter them into chunks and gather the translations back.
      entries = []
      data["phrases"].each_with_index do |phrase, p_index|
        Array(phrase["words"]).each_with_index do |word, w_index|
          entries << {
            phrase_index: p_index,
            word_index: w_index,
            line: build_word_line(phrase, w_index)
          }
        end
      end

      return save! if entries.empty?

      chunks = entries.each_slice(WORDS_PER_CHUNK).to_a
      semaphore = Async::Semaphore.new(max_concurrency)

      results = Async do
        tasks = chunks.each_with_index.map do |chunk, index|
          Async do
            semaphore.acquire do
              [ index, translate_chunk(instructions, chunk, max_retries) ]
            end
          end
        end

        tasks.map(&:wait).sort_by(&:first).flat_map(&:last)
      end.wait

      results.each do |entry, translation|
        word = data["phrases"][entry[:phrase_index]]["words"][entry[:word_index]]
        word["translation"] = translation
      end

      save!
    rescue => e
      persist_translation_failures(e)
      raise e
    end

    private

    # Build the input line for one word: the word, its phrase as context with the
    # target word marked, and a trailing "|" for the model to complete.
    #   apateu (Turn this *apateu* into a club) |
    def build_word_line(phrase, word_index)
      words = Array(phrase["words"])
      target = words[word_index]["text"]

      context = words.each_with_index.map do |w, i|
        i == word_index ? "*#{w["text"]}*" : w["text"]
      end.join(" ")

      "#{target} (#{context}) |"
    end

    def translate_chunk(instructions, chunk, max_retries)
      lines = chunk.map { |e| e[:line] }
      retry_count = 0
      response = nil

      loop do
        chat = TracedChat.new(span_name: "add_token_translations", **MODEL_PARAMS)
        chat
          .with_instructions(instructions)
          .add_message role: :user, content: lines.join("\n")

        response = chat.complete

        translations = parse_chunk_translations(response.content.strip, chunk.size)
        return chunk.zip(translations)
      rescue => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = (2 ** retry_count) + rand(1..3)
          Rails.logger.warn "AddTokenTranslations attempt #{retry_count} failed: #{e.message}. Retrying in #{wait_time} seconds..."
          sleep(wait_time)
          retry
        else
          Rails.logger.error "AddTokenTranslations failed after #{max_retries} attempts: #{e.message}"
          # Stash the failing chunk's input and the raw LLM response so we can
          # inspect why parsing failed later (see persist_translation_failures).
          @translation_failures << {
            "occurred_at" => Time.current.iso8601,
            "attempts" => retry_count,
            "error_class" => e.class.name,
            "error_message" => e.message,
            "input_lines" => lines,
            "agent_response" => response&.content
          }
          raise e
        end
      end
    end

    # Writes any captured translation failures (LLM response + error) into
    # `data["errors"]` so a failed course can be debugged after the fact.
    # Runs outside the async reactor, from add_token_translation's rescue.
    def persist_translation_failures(top_level_error)
      failures = Array(@translation_failures)

      # If nothing was captured at the chunk level (e.g. the error came from
      # somewhere other than an LLM call), still record the top-level error.
      if failures.empty?
        failures << {
          "occurred_at" => Time.current.iso8601,
          "error_class" => top_level_error.class.name,
          "error_message" => top_level_error.message,
          "input_lines" => nil,
          "agent_response" => nil
        }
      end

      data["errors"] ||= []
      failures.each { |failure| data["errors"] << failure.merge("step" => "add_token_translations") }
      save!
    rescue => persist_error
      # Never let debug logging mask the real failure.
      Rails.logger.error "Failed to persist translation failures: #{persist_error.class}: #{persist_error.message}"
    end

    # Expects one "<word> (<context>) | <translation>" line per input line, in
    # order. Ignores any lines that don't contain "|", then validates the count.
    def parse_chunk_translations(content, expected_count)
      translations = content.lines
        .map(&:strip)
        .reject(&:blank?)
        .select { |line| line.include?("|") }
        .map { |line| line.split("|", 2).last.to_s.strip }

      if translations.size != expected_count
        raise "Word translation count mismatch: got #{translations.size}, expected #{expected_count}"
      end

      translations
    end
  end
end
