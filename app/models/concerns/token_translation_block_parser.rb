require 'active_support/concern'

module TokenTranslationBlockParser
  extend ActiveSupport::Concern

  def parse(llm_response_block)
    return [] if llm_response_block.blank?

    lines = llm_response_block.strip.split("\n").reject { |line| line.strip.empty? || line.strip.start_with?('#') }
    words_l1 = text_l1.split(/\s+/).map(&:strip)
    words_l2 = text_l2.split(/\s+/).map(&:strip)

    translations = []

    lines.each do |line|
      parts = line.split('=>', 2)
      next if parts.length != 2

      left, right = parts.map(&:strip)

      l1_match = left.match(/\[(.*?)\]/)
      next unless l1_match

      token_l1 = l1_match[1].strip

      l1_start, l1_end = find_word_indices(words_l1, token_l1)
      next unless l1_start

      right_clean = right.split('#', 2)[0].strip

      l2_start = nil
      l2_end = nil
      translation = right_clean

      l2_match = right_clean.match(/\[(.*?)\]/)
      if l2_match
        token_l2 = l2_match[1].strip
        l2_start, l2_end = find_word_indices(words_l2, token_l2)
        translation = token_l2 if l2_start
      end

      translations << {
        phrase_id: id,
        l1_start_index: l1_start,
        l1_end_index: l1_end,
        l2_start_index: l2_start,
        l2_end_index: l2_end,
        translation: translation,
        questions: [],
        similar_sound: []
      }
    end

    translations
  end

  private

  def find_word_indices(words, token)
    token_words = token.split(/\s+/).map(&:strip)
    num_words = token_words.length

    return nil if num_words == 0

    (0...(words.length - num_words + 1)).each do |start_idx|
      candidate_words = words[start_idx, num_words]
      candidate = candidate_words.join(' ')

      if normalize_for_match(candidate) == normalize_for_match(token)
        return [start_idx, start_idx + num_words - 1]
      end
    end

    nil
  end

  def normalize_for_match(str)
    str.gsub(/[^\w\s]/, '').strip
  end
end
