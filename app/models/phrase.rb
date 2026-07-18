class Phrase < ApplicationRecord
  include AzureTextToSpeech
  include TokenTranslationBlockParser
  include WordTokenBuilder
  belongs_to :medium

  belongs_to :l1, class_name: "Language"
  has_many :phrase_translations, dependent: :destroy, inverse_of: :phrase
  has_one :localized_translation,
          -> { where(language_id: Current.translation_language_id) },
          class_name: "PhraseTranslation"
  has_many :phrase_tokens, dependent: :destroy
  has_many :similar_sounds, dependent: :destroy

  # Validations
  validates :text_l1, presence: { message: "must be present" }
  def text_l2 = localized_translation&.text
  def l2 = localized_translation&.language || Current.translation_language

  has_timestamp [ :timestamp ]

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
    "(split_part(timestamp, ':', 1)::float * 60 + split_part(timestamp, ':', 2)::float) BETWEEN ? AND ?",
    from, to
  )
  }

  # Convert seconds to an "MM:SS.ss" timestamp string. Delegates to HasTimestamp,
  # the single source of truth for timestamp conversions.
  def self.to_string_timestamp(timestamp_seconds)
    HasTimestamp.seconds_to_timestamp(timestamp_seconds)
  end

  # Inverse of to_string_timestamp: parse an "MM:SS.ss" / "HH:MM:SS.ss" string
  # into float seconds, defaulting to 0.0 for blank/malformed input.
  def self.timestamp_to_seconds(timestamp)
    HasTimestamp.timestamp_to_seconds(timestamp) || 0.0
  end

end
