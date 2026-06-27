require "active_support/concern"

# Builds TokenTranslation records from word-timed transcription data (see
# WordTimingParser). Each word becomes a character-indexed token carrying its
# own start/end timestamp (for karaoke highlighting) and translation. These
# tokens intentionally have no L2 indices -- they cannot be used for language
# alignment activities, only word-level lookup and karaoke.
module WordTokenBuilder
  extend ActiveSupport::Concern

  # words: array of { "text" =>, "translation" =>, "timestamp" =>, "timestamp_end" => }
  def build_word_tokens(words)
    return self if words.blank? || text_l1.blank?

    cursor = 0
    tokens = []

    Array(words).each do |word|
      text = word["text"].to_s
      translation = word["translation"].to_s
      next if text.blank? || translation.blank?

      # Locate the word in text_l1 starting from the previous match, so repeated
      # words map to their correct occurrence even with punctuation/spacing quirks.
      start_char = text_l1.index(text, cursor)
      next unless start_char

      end_char = start_char + text.length - 1
      cursor = end_char + 1

      token = token_translations.build(
        l1_start_index: start_char,
        l1_end_index: end_char,
        translation: translation,
        index_type: :character_index,
        start_timestamp: word["timestamp"],
        end_timestamp: word["timestamp_end"]
      )

      if token.valid?
        tokens << token
      else
        Rails.logger.warn "Skipping invalid word token #{text.inspect} in #{text_l1.inspect}: #{token.errors.full_messages.join(', ')}"
      end
    end

    self.token_translations = tokens
    self
  end
end
