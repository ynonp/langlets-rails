require 'active_support/concern'

module TokenTranslationBlockParser
  extend ActiveSupport::Concern

  # llm_response_block
  # 
  # [Pensé] que era un buen momento => [I thought] it was a good time
  # Pensé que [era] un buen momento => I thought [it was] a good time
  # Pensé que era [un] buen momento => I thought it was [a] good time
  # Pensé que era un [buen] momento => I thought it was a [good] time
  # Pensé que era un buen [momento] => moment, time

  def add_tokens_from(llm_response_block)
    return self if llm_response_block.blank?

    llm_response_block.lines.map {|l| l.sub(/\s*#.*$/, '').strip }.each do |line_without_comment|
      process_line(line_without_comment)
    end
    self
  end

  private

  def process_line(line)
    return unless token_translations_line?(line)

    l1, l2 = line.split(/\s*=>\s*/)
    if l2.delete('[]') != text_l2
      create_custom_translation_from_brackets(l1, l2)
    elsif l2.include?('[')
      # l2 contains brackets so it's a regular translation
      create_mapping_token(l1, l2)
    else
      # no bracket in l2, use custom translation
      create_custom_translation_token(l1, l2)
    end
  end

  def create_custom_translation_token(l1, l2)
    l1_start_word_index = find_start_word_index(l1)
    l1_end_word_index = find_end_word_index(l1)

    token_translations.build(
      l1_start_index: l1_start_word_index,
      l1_end_index: l1_end_word_index,
      translation: l2,
    )
  end

  def create_mapping_token(l1, l2)
    l1_start_word_index = find_start_word_index(l1)
    l1_end_word_index = find_end_word_index(l1)
    l2_start_word_index = find_start_word_index(l2)
    l2_end_word_index = find_end_word_index(l2)

    token = token_translations.build(
      l1_start_index: l1_start_word_index,
      l1_end_index: l1_end_word_index,
      l2_start_index: l2_start_word_index,
      l2_end_index: l2_end_word_index,
    )
    raise token.errors.full_messages.join("\n") unless token.valid?
    token.translation = text_l2.tokenize.map(&:to_s)[l2_start_word_index..l2_end_word_index].join(' ')
  end

  def create_custom_translation_from_brackets(l1, l2)
    l1_start_word_index = find_start_word_index(l1)
    l1_end_word_index = find_end_word_index(l1)
    l2_start_word_index = find_start_word_index(l2)
    l2_end_word_index = find_end_word_index(l2)

    token = token_translations.build(
      l1_start_index: l1_start_word_index,
      l1_end_index: l1_end_word_index,
      translation: l2.tokenize.map(&:to_s)[l2_start_word_index..l2_end_word_index].join(' ')
    )
  end


  def find_start_word_index(text)
    start_character = text.index('[')
    word_start_indexes = text.tokenize.map {|t| t.begin(0) - 1 }
    word_start_indexes.find_index {|i| i == start_character }
  end

  def find_end_word_index(text)
    end_character = text.index(']')
    word_end_indexes = text.tokenize.map {|t| t.end(0) }
    word_end_indexes.find_index {|i| i == end_character }
  end

  def token_translations_line?(line)
    return false if line.blank?
    left, right = line.split(/\s*=>\s*/)
    return false if left.blank? || right.blank?
    return false unless (left.include?('[') && left.include?(']'))
    
    true
  end
end
