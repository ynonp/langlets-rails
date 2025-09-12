class Phrase < ApplicationRecord
  include AzureTextToSpeech
  include TokenTranslationBlockParser
  belongs_to :medium

  belongs_to :l1, class_name: 'Language'
  belongs_to :l2, class_name: 'Language'
  has_many :token_translations, dependent: :destroy

  # Validations
  validates :text_l1, presence: { message: "must be present" }
  validates :text_l2, presence: { message: "must be present" }

  has_timestamp [:timestamp]

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

  include TokenTranslationBlockParser
end
