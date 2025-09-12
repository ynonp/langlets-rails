class TokenTranslationParser
  def initialize(phrases, llm_response)
    @phrases = phrases
    @llm_response = llm_response
    @blocks = split_into_blocks(llm_response)
  end

  def call
    all_translations = []

    @phrases.each_with_index do |phrase, idx|
      block = @blocks[idx]
      next unless block

      next unless matches_phrase?(block, phrase)

      translations = phrase.parse(block)
      all_translations.concat(translations)
    end

    all_translations
  end

  private

  def split_into_blocks(response)
    response.to_s.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
  end

  def matches_phrase?(block, phrase)
    lines = block.split("\n")
    phrase_text = phrase.text_l1.strip
    lines.any? do |line|
      parts = line.split('=>', 2)
      next unless parts.length == 2
      left_side = parts[0].strip
      left_clean = left_side.gsub(/\[.*?\]/, '').strip
      phrase_text.include?(left_clean)
    end
  end
end
