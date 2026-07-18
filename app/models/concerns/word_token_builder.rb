require "active_support/concern"

# Builds PhraseToken spans and their localized TokenTranslation rows from
# word-timed transcription data (see WordTimingParser).
module WordTokenBuilder
  extend ActiveSupport::Concern

  # words: array of { "text" =>, "translation" =>, "timestamp" =>, "timestamp_end" =>,
  #                    "l1_start_index" =>, "l1_end_index" => }
  def build_word_tokens(words, language: Current.translation_language)
    return self if words.blank? || text_l1.blank?
    language ||= l2
    raise ArgumentError, "translation language is required" unless language

    cursor = 0
    tokens = []

    Array(words).each do |word|
      text = word["text"].to_s
      translation = word["translation"].to_s
      next if text.blank? || translation.blank?

      # Prefer the character indices computed during extract_lyrics (see
      # WordTimingParser#assign_l1_indices). Fall back to locating the word in
      # text_l1 from the previous match, so repeated words still map to their
      # correct occurrence even with punctuation/spacing quirks.
      start_char = word["l1_start_index"] || text_l1.index(text, cursor)
      next unless start_char

      end_char = word["l1_end_index"] || (start_char + text.length - 1)
      cursor = end_char + 1

      token = phrase_tokens.find_or_initialize_by(
        l1_start_index: start_char,
        l1_end_index: end_char,
        index_type: :character_index
      )
      token.assign_attributes(
        start_timestamp: word["timestamp"],
        end_timestamp: word["timestamp_end"]
      )
      if token.valid?
        token.save! if persisted?
        if language && translation.present?
          token.token_translations.find_or_initialize_by(language: language).tap do |localized|
            localized.translation = translation
            localized.save! if token.persisted?
          end
        end
        tokens << token
      else
        Rails.logger.warn "Skipping invalid word token #{text.inspect} in #{text_l1.inspect}: #{token.errors.full_messages.join(', ')}"
      end
    end

    unless persisted?
      self.phrase_tokens = tokens
    end
    self
  end
end
