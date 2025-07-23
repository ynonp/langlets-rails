class Phrase < ApplicationRecord
  include AzureTextToSpeech
  
  belongs_to :medium
  belongs_to :l1, class_name: :Language
  belongs_to :l2, class_name: :Language
  has_many :token_translations, dependent: :destroy
  has_one_attached :l1_audio, service: :s3_public
  has_timestamp [:timestamp]

  # Callbacks to automatically generate l1_audio when text_l1 or l1 language changes
  after_create :generate_l1_audio, if: :should_generate_audio?
  after_update :generate_l1_audio, if: :should_generate_audio_on_update?

  scope :ordered_by_timestamp, -> { order(timestamp: :asc) }

  # Class method to add calculated_end_timestamp to each phrase based on the next phrase in the medium
  def self.with_calculated_end_timestamps(phrase_collection, all_medium_phrases = nil)
    phrase_collection.each do |phrase|
      # Use provided medium phrases or fetch them
      medium_phrases = all_medium_phrases || phrase.medium.phrases.ordered_by_timestamp.to_a
      
      # Find the next phrase in the medium's phrase collection
      current_phrase_index = medium_phrases.find_index { |p| p.id == phrase.id }
      next_phrase = current_phrase_index ? medium_phrases[current_phrase_index + 1] : nil
      
      # Calculate end timestamp using next phrase or default to +5 seconds
      timestamp_end = next_phrase&.timestamp || to_string_timestamp(phrase.timestamp_seconds + 5)
      
      # Add the calculated end timestamp as a singleton method
      phrase.define_singleton_method(:calculated_end_timestamp) { timestamp_end }
    end
    
    phrase_collection
  end

  scope :between_durations, ->(from, to) {
  where(
    "(split_part(timestamp, ':', 1)::int * 60 + split_part(timestamp, ':', 2)::int) BETWEEN ? AND ?",
    from, to
  )
  }

  # Class method to convert seconds to timestamp string format ("MM:SS")
  def self.to_string_timestamp(timestamp_seconds)
    minutes = timestamp_seconds / 60
    seconds = timestamp_seconds % 60
    "#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end

  def add_token_translation(text, text_occurrence, translation, translation_occurrence, **attributes)
    l1_words = tokenize(text_l1)
    l2_words = tokenize(text_l2)
    
    # Find word indexes for L1 text
    l1_word_indexes = find_word_indexes(l1_words, text, text_occurrence)
    if l1_word_indexes.nil?
      Rails.logger.error("Couldn't find text '#{text}' occurrence #{text_occurrence} in L1 phrase: #{text_l1}")
      return nil
    end

    # Find word indexes for L2 text (optional)
    l2_word_indexes = nil
    if translation_occurrence >= 0 && translation.present?
      l2_word_indexes = find_word_indexes(l2_words, translation, translation_occurrence)
      if l2_word_indexes.nil?
        Rails.logger.warn("Couldn't find translation '#{translation}' occurrence #{translation_occurrence} in L2 phrase: #{text_l2}")
      end
    end

    # Validate continuous indexes
    unless continuous_indexes?(l1_word_indexes)
      Rails.logger.error("Non-continuous L1 word indexes for '#{text}'. Skipping token translation.")
      return nil
    end

    if l2_word_indexes && !continuous_indexes?(l2_word_indexes)
      Rails.logger.error("Non-continuous L2 word indexes for '#{translation}'. Skipping token translation.")
      return nil
    end

    begin
      TokenTranslation.create!(
        phrase: self,
        l1_start_index: l1_word_indexes.first,
        l1_end_index: l1_word_indexes.last,
        l2_start_index: l2_word_indexes&.first,
        l2_end_index: l2_word_indexes&.last,
        translation: translation,
        **attributes
      )
    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.error("Duplicate token translation for phrase #{self.id}. Skipping. Error: #{e.message}")
      return nil
    end
  end

  def find_token_translation(text, text_index=0)
    l1_words = tokenize(text_l1)
    target_word_indexes = find_word_indexes(l1_words, text, text_index)
    return nil if target_word_indexes.nil?

    result = self.token_translations.find_by(
      l1_start_index: target_word_indexes.first,
      l1_end_index: target_word_indexes.last
    )
    
    if result.nil?
      Rails.logger.debug("No token translation found for '#{text}' at word indexes #{target_word_indexes}")
    end
    
    result
  end

  def create_mappings
    tokens = Ai::Gemini.extract_keywords_from_phrases(
      text_l1,
      text_l2,
      l1.english_name,
      l2.english_name)

    tokens.map do |token|
      start_index = token["l1_index"].to_i
      token_text = token["l1_text"]
      token_translation = token["l2_text"]
      token_questions = token["l1_questions"]
      end_index = start_index + token_text.length

      l2_start_index = token["l2_index"].to_i
      l2_end_index = l2_start_index + token_translation.length

      extracted = text_l1[start_index...end_index]
      next if extracted != token_text

      code = <<END
      TokenTranslation.find_or_create_by(
        phrase: phrase,
        l1_start_index: #{start_index},
        l1_end_index: #{end_index}
      ) do |token|
        token.questions = #{(token_questions || []).to_s}
        token.translation = "#{token_translation}"
        token.l2_start_index = #{l2_start_index}
        token.l2_end_index = #{l2_end_index}
      end
END
      puts code
      code
    end
  end

  private

  def tokenize(text)
    text.scan(/\p{L}+(?:'\p{L}+)*/u)
  end

  def find_word_indexes(words, target_text, occurrence)
    target_words = tokenize(target_text)
    return nil if target_words.empty?

    occurrences_found = 0
    
    (0..words.length - target_words.length).each do |start_idx|
      if words[start_idx, target_words.length] == target_words
        if occurrences_found == occurrence
          return (start_idx..start_idx + target_words.length - 1).to_a
        end
        occurrences_found += 1
      end
    end

    nil
  end

  def continuous_indexes?(indexes)
    return false if indexes.nil? || indexes.empty?
    indexes.each_cons(2).all? { |a, b| b == a + 1 }
  end

  # Check if we should generate audio on create
  def should_generate_audio?
    text_l1.present? && l1&.iso_name.present?
  end

  # Check if we should generate audio on update (only if text_l1 or l1 changed)
  def should_generate_audio_on_update?
    should_generate_audio? && (saved_change_to_text_l1? || saved_change_to_l1_id?)
  end

  # Generate and attach l1_audio using Azure Text-to-Speech in background job
  def generate_l1_audio
    return unless text_l1.present? && l1&.iso_name.present?

    begin
      Rails.logger.info "Queueing l1_audio generation for Phrase #{id}: '#{text_l1}' (#{l1.iso_name})"
      
      # Queue the audio generation job to run in background
      GeneratePhraseAudioJob.perform_later(id)
      
      Rails.logger.info "Successfully queued l1_audio generation job for Phrase #{id}"
      
    rescue => e
      Rails.logger.error "Error queueing l1_audio generation for Phrase #{id}: #{e.message}"
      # Don't raise the error to avoid breaking the save operation
      # Just log it and continue
    end
  end
end
