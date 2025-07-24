class TokenTranslation < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :phrase
  has_one_attached :l1_audio, service: :s3_public

  # Generate audio when token is created
  after_create :generate_l1_audio, if: :should_generate_audio?
  
  # Regenerate audio when indices change (affecting the original_text)
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  scope :with_questions, ->() {
    where("questions is not null and cardinality(questions) > 0")
  }

  def original_text
    return "" if l1_start_index.nil? || l1_end_index.nil?
    
    phrase_text = phrase.text_l1
    return "" if phrase_text.blank?
    
    words = phrase_text.tokenize
    return "" if l1_start_index < 0 || l1_end_index >= words.length || l1_start_index > l1_end_index
    
    words[l1_start_index..l1_end_index].join(" ")
  end

  # Convert word-based indices to character-based indices for L1 text
  # Returns the character position where the word at l1_start_index begins
  # Handles multiple occurrences of the same word correctly
  def l1_start_character_index
    return nil if l1_start_index.nil?
    
    phrase_text = phrase.text_l1
    return nil if phrase_text.blank?
    
    words = phrase_text.tokenize
    return nil if l1_start_index >= words.length || l1_start_index < 0
    
    # Find the character position where the word starts
    target_word = words[l1_start_index]
    find_character_index_for_word(phrase_text, target_word, l1_start_index, words)
  end

  # Returns the character position where the word at l1_end_index ends (inclusive)
  # Handles multiple occurrences of the same word correctly
  def l1_end_character_index
    return nil if l1_end_index.nil?
    
    phrase_text = phrase.text_l1
    return nil if phrase_text.blank?
    
    words = phrase_text.tokenize
    return nil if l1_end_index >= words.length || l1_end_index < 0
    
    # Find the character position where the word ends (inclusive)
    target_word = words[l1_end_index]
    start_char = find_character_index_for_word(phrase_text, target_word, l1_end_index, words)
    return nil if start_char.nil?
    
    start_char + target_word.length
  end

  # Convert word-based indices to character-based indices for L2 text
  # Returns the character position where the word at l2_start_index begins
  # Handles multiple occurrences of the same word correctly
  def l2_start_character_index
    return nil if l2_start_index.nil?
    
    phrase_text = phrase.text_l2
    return nil if phrase_text.blank?
    
    words = phrase_text.tokenize
    return nil if l2_start_index >= words.length || l2_start_index < 0
    
    # Find the character position where the word starts
    target_word = words[l2_start_index]
    find_character_index_for_word(phrase_text, target_word, l2_start_index, words)
  end

  # Returns the character position where the word at l2_end_index ends (inclusive)
  # Handles multiple occurrences of the same word correctly
  def l2_end_character_index
    return nil if l2_end_index.nil?
    
    phrase_text = phrase.text_l2
    return nil if phrase_text.blank?
    
    words = phrase_text.tokenize
    return nil if l2_end_index >= words.length || l2_end_index < 0
    
    # Find the character position where the word ends (inclusive)
    target_word = words[l2_end_index]
    start_char = find_character_index_for_word(phrase_text, target_word, l2_end_index, words)
    return nil if start_char.nil?
    
    start_char + target_word.length
  end

  private

  # Helper method to find character index of a specific word occurrence
  def find_character_index_for_word(text, target_word, word_index, words)
    # Count how many times we've seen this word before the target index
    occurrence = 0
    (0...word_index).each do |i|
      occurrence += 1 if words[i] == target_word
    end
    
    # Find the nth occurrence of the word in the text
    current_occurrence = 0
    text.scan(/\p{L}+(?:'\p{L}+)*/u) do |word|
      if word == target_word
        return Regexp.last_match.begin(0) if current_occurrence == occurrence
        current_occurrence += 1
      end
    end
    
    nil
  end

  def should_generate_audio?
    # Generate audio if we have text and a language
    original_text.present? && phrase&.l1&.iso_name.present?
  end

  def should_generate_audio_on_update?
    # Generate audio if indices changed (which affects original_text) and we have the necessary data
    (saved_change_to_l1_start_index? || saved_change_to_l1_end_index?) && should_generate_audio?
  end

  def generate_l1_audio
    # Queue background job for audio generation
    GenerateTokenAudioJob.perform_later(id)
  end
end
