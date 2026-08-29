class Phrase < ApplicationRecord
  include AzureTextToSpeech
  include TokenTranslationBlockParser
  include WordTokenBuilder
  # A phrase has exactly one source: imported/course phrases belong to playable
  # media, while vocabulary typed by a user belongs directly to that user.
  belongs_to :medium, optional: true
  belongs_to :user, optional: true

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
  validate :has_exactly_one_source

  def custom? = user_id.present?
  def text_l2 = localized_translation&.text
  def l2 = localized_translation&.language || Current.translation_language

  has_timestamp [ :timestamp ]

  scope :ordered_by_timestamp, -> { order(timestamp: :asc) }

  # Operator-facing repair helpers. Indexes are inclusive in PhraseToken.
  def correct_text(old_text, new_text)
    raise ArgumentError, "old_text must equal the complete phrase text" unless text_l1 == old_text
    raise ArgumentError, "new_text must not be empty" if new_text.blank?

    tokens = phrase_tokens.to_a
    index_type = uniform_token_index_type!(tokens)
    index_mapping = unchanged_index_mapping(old_text, new_text, index_type)
    preserved_tokens = tokens.select do |token|
      mapped_range(index_mapping, token[:l1_start_index], token[:l1_end_index])
    end
    deleted_tokens = tokens - preserved_tokens
    affected_activities = ActivityPhraseToken
      .where(phrase_token_id: deleted_tokens.map(&:id))
      .group(:activity_id)
      .count
      .to_h { |activity_id, count| [ Activity.find(activity_id), count ] }

    transaction do
      update!(text_l1: text_l1.sub(old_text, new_text))
      deleted_tokens.each(&:destroy!)

      preserved_tokens.each do |token|
        new_start, new_end = mapped_range(
          index_mapping,
          token[:l1_start_index],
          token[:l1_end_index]
        )
        token.update!(
          l1_start_index: new_start,
          l1_end_index: new_end
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
      medium_phrases = all_medium_phrases ||
        phrase.medium&.phrases&.ordered_by_timestamp&.to_a ||
        [ phrase ]

      # Find the next phrase in the medium's phrase collection
      current_phrase_index = medium_phrases.find_index { |p| p.id == phrase.id }
      next_phrase = current_phrase_index ? medium_phrases[current_phrase_index + 1] : nil

      # Calculate end timestamp using next phrase or default to +5 seconds
      timestamp_end = next_phrase&.timestamp
      timestamp_end ||= to_string_timestamp(phrase.timestamp_seconds + 5) if phrase.timestamp_seconds

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

  def has_exactly_one_source
    return if [ medium, user ].compact.one?

    errors.add(:base, "must belong to either a medium or a user, but not both")
  end

  def uniform_token_index_type!(tokens)
    index_types = tokens.map(&:index_type).uniq
    return @correction_index_type if index_types.empty? && @correction_index_type
    raise ArgumentError, "phrase must have at least one phrase token" if index_types.empty?
    raise ArgumentError, "all phrase tokens must use the same index_type" unless index_types.one?

    index_types.first
  end

  def unchanged_index_mapping(old_text, new_text, index_type)
    old_units = correction_units(old_text, index_type)
    new_units = correction_units(new_text, index_type)
    lengths = Array.new(old_units.length + 1) { Array.new(new_units.length + 1, 0) }

    (old_units.length - 1).downto(0) do |old_index|
      (new_units.length - 1).downto(0) do |new_index|
        lengths[old_index][new_index] =
          if old_units[old_index] == new_units[new_index]
            lengths[old_index + 1][new_index + 1] + 1
          else
            [ lengths[old_index + 1][new_index], lengths[old_index][new_index + 1] ].max
          end
      end
    end

    mapping = {}
    old_index = 0
    new_index = 0
    while old_index < old_units.length && new_index < new_units.length
      if old_units[old_index] == new_units[new_index]
        mapping[old_index] = new_index
        old_index += 1
        new_index += 1
      elsif lengths[old_index + 1][new_index] >= lengths[old_index][new_index + 1]
        old_index += 1
      else
        new_index += 1
      end
    end
    mapping
  end

  def correction_units(text, index_type)
    index_type == "character_index" ? text.chars : text.tokenize.map(&:to_s)
  end

  def mapped_range(index_mapping, start_index, end_index)
    mapped_indexes = (start_index..end_index).map { |index| index_mapping[index] }
    return if mapped_indexes.any?(&:nil?)
    return unless mapped_indexes.each_cons(2).all? { |left, right| right == left + 1 }

    [ mapped_indexes.first, mapped_indexes.last ]
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
end
