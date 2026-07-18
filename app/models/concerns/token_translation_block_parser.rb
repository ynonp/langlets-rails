require "active_support/concern"

module TokenTranslationBlockParser
  extend ActiveSupport::Concern

  def add_tokens_from(llm_response_block)
    return self if llm_response_block.blank?

    llm_response_block.lines.map { |l| l.sub(/\s*#.*$/, "").strip }.each do |line_without_comment|
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
    line_without_brackets = line.delete("[]")

    while s.scan_until(/\[/)
      iterations += 1

      start_bracket_ch_index = s.charpos
      start_ch_index = s.charpos - 1 - 2 * (iterations - 1)
      s.scan_until(/\]/)

      end_bracket_ch_index = s.charpos
      end_ch_index = s.charpos - 3 - 2 * (iterations - 1)

      start_word_index = line_without_brackets.tokenize.map { |t| t.begin(0) }.find_index { |i| i == start_ch_index }
      end_word_index = line_without_brackets.tokenize.map { |t| t.end(0) - 1 }.find_index { |i| i == end_ch_index }
      replacement_text = line_without_brackets[start_ch_index..end_ch_index]

      similar_sounds.build(
        start_word_index:,
        end_word_index:,
        replacement_text:,
      )
    end
  end

  private

  def preprocess_alignment(line)
    return line unless l1&.iso_name

    case l1.iso_name
    when /\Aar/ then preprocess_arabic_alignment(line)
    else line
    end
  end

  def preprocess_arabic_alignment(line)
    left, right = line.split(/\s*=>\s*/, 2)
    return line unless left && right

    # Remove spaces after و (the Arabic conjunction) if the original text
    # doesn't have them. The AI sometimes adds these spaces in alignments.
    alignment_text = left.delete("[]")
    fixed_text = alignment_text.gsub(/(و)\s+/, '\1')

    return line if fixed_text == alignment_text
    return line unless text_l1&.include?(fixed_text)

    fixed_left = left.gsub(/(و\]?)\s+/, '\1')
    "#{fixed_left} => #{right}"
  end

  def process_line(line)
    return unless token_translations_line?(line)

    line = preprocess_alignment(line)

    l1_with_brackets, l2_with_brackets = line.split(/\s*=>\s*/).map(&:strip)

    l1_text = l1_with_brackets.delete("[]")
    l1_match = find_substring_match(l1_text, text_l1)
    return unless l1_match

    l1_offset = l1_match[:prefix_length]

    if !l2_with_brackets.include?("[")
      create_custom_translation_token(l1_with_brackets, l2_with_brackets, l1_offset: l1_offset)
    elsif l2_with_brackets.delete("[]").downcase != text_l2.downcase
      create_custom_translation_from_brackets(l1_with_brackets, l2_with_brackets, l1_offset: l1_offset)
    else
      create_mapping_token(l1_with_brackets, l2_with_brackets, l1_offset: l1_offset)
    end
  end

  def create_custom_translation_token(l1_with_brackets, l2, l1_offset: 0)
    l1_text = l1_with_brackets.delete("[]")
    l1_start_char, l1_end_char = find_char_range_in_text(l1_with_brackets, l1_text)

    return if l1_start_char.nil? || l1_end_char.nil?

    build_phrase_token(
      {
      l1_start_index: l1_start_char + l1_offset,
      l1_end_index: l1_end_char + l1_offset,
      index_type: :character_index
      },
      { translation: l2 }
    )
  end

  def create_mapping_token(l1_with_brackets, l2_with_brackets, l1_offset: 0)
    l1_text = l1_with_brackets.delete("[]")
    l2_text = l2_with_brackets.delete("[]")

    l1_start_char, l1_end_char = find_char_range_in_text(l1_with_brackets, l1_text)
    l2_start_char, l2_end_char = find_char_range_in_text(l2_with_brackets, l2_text)

    return if l1_start_char.nil? || l1_end_char.nil? || l2_start_char.nil? || l2_end_char.nil?

    l2_words = l2_text.split
    l2_start_word = char_to_word_index(l2_start_char, l2_text)
    l2_end_word = char_to_word_index(l2_end_char, l2_text, inclusive: true)

    token = build_phrase_token(
      {
      l1_start_index: l1_start_char + l1_offset,
      l1_end_index: l1_end_char + l1_offset,
      index_type: :character_index
      },
      {
      l2_start_index: l2_start_char,
      l2_end_index: l2_end_char,
      translation: l2_words[l2_start_word..l2_end_word].join(" ")
      }
    )

    unless token.valid?
      Rails.logger.warn "Skipping invalid token translation: #{l1_with_brackets} => #{l2_with_brackets}. Errors: #{token.errors.full_messages.join(', ')}"
      return
    end

    token
  end

  def create_custom_translation_from_brackets(l1_with_brackets, l2_with_brackets, l1_offset: 0)
    l1_text = l1_with_brackets.delete("[]")
    l1_start_char, l1_end_char = find_char_range_in_text(l1_with_brackets, l1_text)

    return if l1_start_char.nil? || l1_end_char.nil?

    l2_text = l2_with_brackets.delete("[]")
    l2_start_char, l2_end_char = find_char_range_in_text(l2_with_brackets, l2_text)

    l2_words = l2_text.split
    l2_start_word = char_to_word_index(l2_start_char, l2_text)
    l2_end_word = char_to_word_index(l2_end_char, l2_text, inclusive: true)

    translation_text = l2_words[l2_start_word..l2_end_word].join(" ")

    build_phrase_token(
      {
      l1_start_index: l1_start_char + l1_offset,
      l1_end_index: l1_end_char + l1_offset,
      index_type: :character_index
      },
      { translation: translation_text }
    )
  end

  def find_char_range_in_text(text_with_brackets, text_without_brackets)
    bracket_start = text_with_brackets.index("[")
    return nil unless bracket_start

    bracket_end = text_with_brackets.index("]")
    return nil unless bracket_end

    start_pos_marked = bracket_start + 1
    end_pos_marked = bracket_end - 1

    start_char = start_pos_marked - text_with_brackets[0...start_pos_marked].count("[]")
    end_char = end_pos_marked - text_with_brackets[0...end_pos_marked].count("[]")

    [ start_char, end_char ]
  end

  def char_to_word_index(char_index, text, inclusive: false)
    words = text.split
    return nil if words.empty?

    current_pos = 0
    words.each_with_index do |word, idx|
      word_start = current_pos
      word_end = current_pos + word.length - 1

      if char_index >= word_start && char_index <= word_end
        return idx
      end
      current_pos += word.length + 1
    end

    words.length - 1
  end

  def token_translations_line?(line)
    return false if line.blank?
    left, right = line.split(/\s*=>\s*/)
    return false if left.blank? || right.blank?
    return false unless left.include?("[") && left.include?("]")

    true
  end

  def find_substring_match(partial_text, full_text)
    partial_lower = partial_text.downcase
    full_lower = full_text.downcase

    return { prefix_length: 0 } if partial_lower == full_lower

    start_pos = full_lower.index(partial_lower)
    return nil unless start_pos

    { prefix_length: start_pos }
  end

  def remove_duplicate_translations
    words = Hash.new { |h, k| h[k] = [] }

    phrase_tokens.each do |t|
      t.l1_start_index.upto(t.l1_end_index).each do |char_index|
        words[char_index] << t
      end
    end

    words.transform_values! do |tokens|
      [ tokens.min_by(&:span_length) ]
    end

    self.phrase_tokens = words.values.flatten.uniq
  end

  def build_phrase_token(span_attributes, translation_attributes)
    language = l2
    raise ArgumentError, "translation language is required" unless language

    span = phrase_tokens.build(span_attributes)
    localized = span.token_translations.build(translation_attributes.merge(language: language))
    span.resolved_translation = localized
    if persisted?
      span.save!
      localized.save!
    end
    span
  end
end
