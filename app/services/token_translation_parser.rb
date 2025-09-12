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

      translations = phrase.add_tokens_from(block)
    end
  end

  private

  def split_into_blocks(response)
    response.to_s.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
  end
end
