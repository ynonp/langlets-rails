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
  has_many :activity_phrases, dependent: :destroy

  # Validations
  validates :text_l1, presence: { message: "must be present" }
  def text_l2 = localized_translation&.text
  def l2 = localized_translation&.language || Current.translation_language

  has_timestamp [ :timestamp ]

  scope :ordered_by_timestamp, -> { order(timestamp: :asc) }

  # Operator-facing repair helpers. Indexes are inclusive in PhraseToken.
  def correct_text(old_text, new_text)
    raise ArgumentError, "old_text must appear exactly once" unless text_occurrence_indexes(old_text).one?
    raise ArgumentError, "new_text must not be empty" if new_text.blank?
    raise ArgumentError, "new_text must differ from old_text" if new_text == old_text

    tokens = phrase_tokens.to_a
    index_type = uniform_token_index_type!(tokens)
    old_start, old_end, index_delta = correction_indexes(old_text, new_text, index_type)
    deleted_tokens = tokens.select do |token|
      token[:l1_start_index] <= old_end && token[:l1_end_index] >= old_start
    end
    affected_activities = ActivityPhraseToken
      .where(phrase_token_id: deleted_tokens.map(&:id))
      .group(:activity_id)
      .count
      .to_h { |activity_id, count| [ Activity.find(activity_id), count ] }

    transaction do
      update!(text_l1: text_l1.sub(old_text, new_text))
      deleted_tokens.each(&:destroy!)

      (tokens - deleted_tokens).each do |token|
        next unless token[:l1_start_index] > old_end

        token.update!(
          l1_start_index: token[:l1_start_index] + index_delta,
          l1_end_index: token[:l1_end_index] + index_delta
        )
      end
    end

    @correction_index_type = index_type
    phrase_tokens.reset
    affected_activities
  end

  def create_token(text, translation_table)
    raise ArgumentError, "translation_table must be a non-empty hash" unless translation_table.is_a?(Hash) && translation_table.present?
    raise ArgumentError, "translations must not be empty" if translation_table.any? { |language, translation| language.blank? || translation.blank? }

    tokens = phrase_tokens.to_a
    index_type = uniform_token_index_type!(tokens)
    start_index, end_index = first_uncovered_token_range(text, tokens, index_type)
    raise ArgumentError, "#{text.inspect} was not found in an uncovered position" unless start_index

    transaction do
      token = phrase_tokens.create!(
        l1_start_index: start_index,
        l1_end_index: end_index,
        index_type: index_type
      )
      translation_table.each do |iso_name, translation|
        token.token_translations.create!(
          language: Language.find_by!(iso_name: iso_name.to_s),
          translation: translation
        )
      end
      token
    end
  end

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

  private

  def uniform_token_index_type!(tokens)
    index_types = tokens.map(&:index_type).uniq
    return @correction_index_type if index_types.empty? && @correction_index_type
    raise ArgumentError, "phrase must have at least one phrase token" if index_types.empty?
    raise ArgumentError, "all phrase tokens must use the same index_type" unless index_types.one?

    index_types.first
  end

  def correction_indexes(old_text, new_text, index_type)
    character_start = text_l1.index(old_text)
    return [ character_start, character_start + old_text.length - 1, new_text.length - old_text.length ] if index_type == "character_index"

    old_matches = token_matches_inside(character_start, character_start + old_text.length)
    raise ArgumentError, "old_text must align with complete words" unless exact_word_span?(old_matches, character_start, character_start + old_text.length)

    old_start = text_l1.tokenize.take_while { |match| match.begin(0) < character_start }.size
    old_word_count = old_matches.size
    new_word_count = new_text.tokenize.count
    raise ArgumentError, "new_text must contain at least one word" if new_word_count.zero?

    [ old_start, old_start + old_word_count - 1, new_word_count - old_word_count ]
  end

  def first_uncovered_token_range(text, tokens, index_type)
    raise ArgumentError, "text must not be empty" if text.blank?

    character_start = -1
    while (character_start = text_l1.index(text, character_start + 1))
      character_end = character_start + text.length
      candidate = if index_type == "character_index"
        [ character_start, character_end - 1 ]
      else
        matches = token_matches_inside(character_start, character_end)
        next unless exact_word_span?(matches, character_start, character_end)

        word_start = text_l1.tokenize.take_while { |match| match.begin(0) < character_start }.size
        [ word_start, word_start + matches.size - 1 ]
      end

      covered = tokens.any? do |token|
        token[:l1_start_index] <= candidate.last && token[:l1_end_index] >= candidate.first
      end
      return candidate unless covered
    end
    nil
  end

  def token_matches_inside(character_start, character_end)
    text_l1.tokenize.select do |match|
      match.begin(0) >= character_start && match.end(0) <= character_end
    end
  end

  def exact_word_span?(matches, character_start, character_end)
    matches.any? && matches.first.begin(0) == character_start && matches.last.end(0) == character_end
  end

  def text_occurrence_indexes(text)
    return [] if text.blank?

    indexes = []
    cursor = -1
    indexes << cursor while (cursor = text_l1.to_s.index(text, cursor + 1))
    indexes
  end
end
