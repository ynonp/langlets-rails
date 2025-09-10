class PhraseTokenParser
  class ParsedPhrase
    attr_accessor :l1_text, :l2_text, :token_translations
    
    def initialize(l1_text, l2_text)
      @l1_text = l1_text
      @l2_text = l2_text
      @token_translations = []
    end
  end
  
  class TokenTranslation
    attr_accessor :l1_start_index, :l1_end_index, :l2_start_index, :l2_end_index, :translation
    
    def initialize(l1_start_index, l1_end_index, translation, l2_start_index = nil, l2_end_index = nil)
      @l1_start_index = l1_start_index
      @l1_end_index = l1_end_index
      @l2_start_index = l2_start_index
      @l2_end_index = l2_end_index
      @translation = translation
    end
  end

  def initialize(input_text)
    @input_text = input_text
  end

  def parse
    phrases = []
    
    # Split by empty lines to get phrase groups
    phrase_groups = @input_text.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
    
    phrase_groups.each do |group|
      lines = group.split("\n").map(&:strip).reject(&:empty?)
      next if lines.empty?
      
      # First line defines the phrase base
      first_line = lines.first
      phrase = parse_base_phrase_line(first_line)
      next unless phrase
      
      # Process all lines in the group (including the first)
      lines.each do |line|
        token_translation = parse_token_translation_line(line, phrase)
        phrase.token_translations << token_translation if token_translation
      end
      
      phrases << phrase
    end
    
    phrases
  end

  private

  def parse_base_phrase_line(line)
    # Remove comment if present
    line = line.split(' # ').first.strip
    
    parts = line.split(' => ')
    return nil if parts.length != 2
    
    l1_text = parts[0].strip
    l2_text = parts[1].strip
    
    # Extract base text (without brackets)
    l1_base = extract_base_text(l1_text)
    l2_base = extract_base_text(l2_text)
    
    ParsedPhrase.new(l1_base, l2_base)
  end

  def parse_token_translation_line(line, phrase)
    return nil unless phrase
    
    # Remove comment if present
    line = line.split(' # ').first.strip
    
    parts = line.split(' => ')
    return nil if parts.length != 2
    
    l1_text = parts[0].strip
    translation_text = parts[1].strip
    
    # Extract bracketed content from L1
    l1_bracketed, l1_start_idx, l1_end_idx = find_bracketed_content_and_indices(l1_text, phrase.l1_text)
    
    return nil unless l1_bracketed && l1_start_idx && l1_end_idx
    
    # Check if translation has brackets for L2 mapping
    l2_bracketed, l2_start_idx, l2_end_idx = find_bracketed_content_and_indices(translation_text, phrase.l2_text)
    
    # Use bracketed translation if available, otherwise full translation
    final_translation = l2_bracketed || translation_text
    
    TokenTranslation.new(
      l1_start_idx,
      l1_end_idx,
      final_translation,
      l2_start_idx,
      l2_end_idx
    )
  end

  def extract_base_text(text)
    # Remove brackets to get clean text
    text.gsub(/\[[^\]]+\]/) { |match| match[1...-1] }
  end

  def find_bracketed_content_and_indices(text, reference_text)
    # Find bracketed content
    match = text.match(/\[([^\]]+)\]/)
    
    return [nil, nil, nil] unless match
    
    bracketed_content = match[1]
    
    # Find word indices in reference text
    reference_words = reference_text.split
    bracketed_words = bracketed_content.split
    
    start_index, end_index = find_word_indices_in_text(reference_words, bracketed_words, bracketed_content)
    
    [bracketed_content, start_index, end_index]
  end

  def find_word_indices_in_text(reference_words, target_words, target_phrase)
    # For single word
    if target_words.length == 1
      word = target_words[0]
      # Handle special cases like contractions
      if word == "'til"
        word = "'til"  # Keep as is for exact match
      end
      
      index = reference_words.find_index(word)
      return [index, index] if index
      
      # Try fuzzy matching for special cases
      reference_words.each_with_index do |ref_word, i|
        if ref_word.include?(word) || word.include?(ref_word)
          return [i, i]
        end
      end
    else
      # For multi-word phrases, find consecutive matching sequence
      (0..reference_words.length - target_words.length).each do |start_idx|
        match = true
        target_words.each_with_index do |target_word, i|
          if reference_words[start_idx + i] != target_word
            match = false
            break
          end
        end
        
        if match
          end_idx = start_idx + target_words.length - 1
          return [start_idx, end_idx]
        end
      end
    end
    
    # Fallback: try partial matching
    reference_text = reference_words.join(' ')
    if reference_text.include?(target_phrase)
      before_phrase = reference_text.split(target_phrase)[0]
      words_before = before_phrase.empty? ? 0 : before_phrase.split.length
      
      start_index = words_before
      end_index = start_index + target_words.length - 1
      
      return [start_index, end_index] if end_index < reference_words.length
    end
    
    [nil, nil]
  end
end