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
      begin
        process_line(line_without_comment)
      rescue => e
        Rails.logger.warn "Skipping problematic token translation line: #{line_without_comment.inspect}. Error: #{e.message}"
      end
    end
    remove_duplicate_translations
    
    self
  end

  def add_similar_sound_from(line)
    s = StringScanner.new(line)
    iterations = 0
    line_without_brackets = line.delete('[]')

    while s.scan_until(/\[/)
      iterations += 1

      start_bracket_ch_index = s.charpos
      start_ch_index = s.charpos - 1 - 2 * (iterations - 1)
      s.scan_until(/\]/)

      end_bracket_ch_index = s.charpos
      end_ch_index = s.charpos - 3 - 2 * (iterations - 1)

      start_word_index = line_without_brackets.tokenize.map {|t| t.begin(0) }.find_index {|i| i == start_ch_index }
      end_word_index = line_without_brackets.tokenize.map {|t| t.end(0) - 1}.find_index {|i| i == end_ch_index }
      replacement_text = line_without_brackets[start_ch_index..end_ch_index]

      similar_sounds.build(
        start_word_index:,
        end_word_index:,
        replacement_text:,
      )
    end
  end

  private

  def process_line(line)
    return unless token_translations_line?(line)

    l1, l2 = line.split(/\s*=>\s*/).map(&:strip)

    return unless l1.delete('[]').downcase.tokenize.to_a == text_l1.downcase.tokenize.to_a

    if !l2.include?('[')
      # no bracket in l2, use custom translation
      create_custom_translation_token(l1, l2)
    elsif l2.delete('[]').downcase != text_l2.downcase
      create_custom_translation_from_brackets(l1, l2)
    else
      # l2 contains brackets so it's a regular translation
      create_mapping_token(l1, l2)
    end
  end

  def create_custom_translation_token(l1, l2)
    l1_start_word_index = find_start_word_index(l1)
    l1_end_word_index = find_end_word_index(l1)

    return if l1_start_word_index.nil? || l1_end_word_index.nil?

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

    return if l1_start_word_index.nil? || l1_end_word_index.nil? || l2_start_word_index.nil? || l2_end_word_index.nil?

    token = token_translations.build(
      l1_start_index: l1_start_word_index,
      l1_end_index: l1_end_word_index,
      l2_start_index: l2_start_word_index,
      l2_end_index: l2_end_word_index,
    )

    unless token.valid?
      Rails.logger.warn "Skipping invalid token translation: #{l1} => #{l2}. Errors: #{token.errors.full_messages.join(', ')}"
      return
    end

    token.translation = text_l2.tokenize.map(&:to_s)[l2_start_word_index..l2_end_word_index].join(' ')
  end

  def create_custom_translation_from_brackets(l1, l2)
    l1_start_word_index = find_start_word_index(l1)
    l1_end_word_index = find_end_word_index(l1)
    l2_start_word_index = find_start_word_index(l2)
    l2_end_word_index = find_end_word_index(l2)

    return if l1_start_word_index.nil? || l1_end_word_index.nil? || l2_start_word_index.nil? || l2_end_word_index.nil?

    token = token_translations.build(
      l1_start_index: l1_start_word_index,
      l1_end_index: l1_end_word_index,
      translation: l2.tokenize.map(&:to_s)[l2_start_word_index..l2_end_word_index].join(' ')
    )
  end

  def find_start_word_index(text)
    start_character = text.index('[')
    word_start_indexes = text.tokenize.map {|t| t.begin(0) - 1 }
    word_start_indexes.find_index {|i| i >= start_character }
  end

  def find_end_word_index(text)
    end_character = text.index(']')
    word_end_indexes = text.tokenize.map {|t| t.end(0) }
    word_end_indexes.rindex {|i| i <= end_character }
  end

  def token_translations_line?(line)
    return false if line.blank?
    left, right = line.split(/\s*=>\s*/)
    return false if left.blank? || right.blank?
    return false unless (left.include?('[') && left.include?(']'))
    
    true
  end

  def remove_duplicate_translations
    words = Hash.new {|h, k| h[k] = [] }

    token_translations.each do |t|
      t.l1_start_index.upto(t.l1_end_index).each do |word_index|
        words[word_index] << t
      end
    end

    words.transform_values! do |tokens|
      [tokens.min_by(&:span_length)]
    end

    self.token_translations = words.values.flatten.uniq
  end
end
