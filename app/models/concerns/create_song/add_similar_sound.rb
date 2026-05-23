module CreateSong
  module AddSimilarSound
    extend ActiveSupport::Concern

    MIN_WORD_LENGTH = 3
    FUZZYWORD_BIN = Rails.root.join("bin", "fuzzyword").to_s.freeze

    def add_similar_sound
      phrases = data["phrases"].map { |p| p["text_l1"] }

      all_results = []
      lang = fuzzyword_lang_code

      phrases.each do |phrase|
        line = build_similar_sound_line(lang, phrase)
        next if line.nil?
        all_results << line
      end

      data["similar_sounds"] = all_results.join("\n")
      save!
    end

    def similar_sounds_complete?
      data["similar_sounds"].present?
    end

    private

    # Build a line where a random word is replaced with a fuzzyword alternative in [brackets].
    def build_similar_sound_line(lang, phrase)
      words = phrase.tokenize.map {|m| m.to_s }
      eligible = words.each_with_index.select { |w, _| strip_punctuation(w).length >= MIN_WORD_LENGTH }

      return nil if eligible.empty?

      pick = eligible.sample
      raw_word = pick[0]
      original_index = pick[1]

      # Separate trailing punctuation from the actual word (fuzzyword needs clean words)
      word, trailing = strip_and_capture_punctuation(raw_word)

      alternatives = fuzzyword_alternatives(lang, word)
      return phrase if alternatives.empty?

      alternative = alternatives.sample
      words[original_index] = "[#{alternative}]#{trailing}"
      words.join(" ")
    end

    # Remove trailing Unicode punctuation for fuzzyword lookup;
    # returns the cleaned word. For reconstruction we use strip_and_capture_punctuation.
    def strip_punctuation(word)
      word.sub(/\p{P}+\z/, "")
    end

    # Returns [clean_word, trailing_punctuation]
    def strip_and_capture_punctuation(word)
      match = word.match(/\A(.+?)(\p{P}+)\z/)
      match ? [match[1], match[2]] : [word, ""]
    end

    # Call fuzzyword and return up to 3 alternatives (excluding the input word).
    def fuzzyword_alternatives(lang, word)
      return [] unless lang

      escaped = Shellwords.escape(word)
      result = nil
      Dir.chdir(Rails.root) do
        result = `#{FUZZYWORD_BIN} --lang #{lang} #{escaped} 2>&1`
      end

      return [] unless $?.success?

      result.strip
            .split(",")
            .map(&:strip)
            .reject(&:blank?)
            .reject { |alt| alt.casecmp?(word) }
    rescue => e
      Rails.logger.warn "Fuzzyword call failed for word '#{word}': #{e.message}"
      []
    end

    # Map clip_language to fuzzyword's language codes.
    def fuzzyword_lang_code
      base_code = Language.find_by(english_name: clip_language)&.iso_name
      return nil unless base_code

      # Fuzzyword uses bare ISO codes; strip country/region suffixes (e.g. ar-JO → ar)
      base_code.sub(/\-.*$/, "")
    end
  end
end



