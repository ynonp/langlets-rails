class PhraseTokenUser < ApplicationRecord
  CUSTOM_SOURCE = "Added by you".freeze
  LEADING_JUNK = /\A[^\p{L}\p{N}]+/u
  TRAILING_JUNK = /[^\p{L}\p{N}]+\z/u

  class InputError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.to_s)
    end
  end

  class InvalidInput < StandardError; end

  belongs_to :user
  belongs_to :phrase_token
  belongs_to :language
  before_validation :pin_available_language, on: :create
  after_commit :refresh_review_lesson, on: [ :create, :update, :destroy ]

  validates :phrase_token_id, uniqueness: { scope: :user_id }

  attr_writer :resolved_source

  # "Stop practising" keeps the word in the vocabulary list but takes it out of
  # every review lesson. Anything that builds or offers a review filters on
  # `practising`; anything that lists vocabulary does not.
  scope :practising, -> { where(practicing: true) }
  scope :paused, -> { where(practicing: false) }

  def practising? = practicing?
  def paused? = !practicing?

  def token = phrase_token
  def phrase = phrase_token.phrase
  def source_language = phrase.l1
  def translation_language = language
  def word = phrase_token.original_text
  def translation = token_translation&.translation
  def context = phrase.text_l1.to_s

  def before
    return context if span.nil?

    context[0...span.first].to_s
  end

  def mark
    return "" if span.nil?

    context[span.first..span.last].to_s
  end

  def after
    return "" if span.nil?

    context[(span.last + 1)..].to_s
  end

  def source
    return CUSTOM_SOURCE if custom?
    return @resolved_source if defined?(@resolved_source)

    phrase.medium&.lessons&.first&.course&.name
  end

  def custom? = phrase.custom?
  def searchable = [ word, translation, context ].compact.join(" ").downcase

  def token_translation
    phrase_token.token_translations.find { |row| row.language_id == language_id } ||
      phrase_token.token_translations.find_by(language_id: language_id)
  end

  class << self
    def with_sources(records)
      sources = sources_for(records)
      records.each { |record| record.resolved_source = sources[record.phrase.medium_id] }
    end

    def create_custom!(user:, sentence:, language:, token_range:, translation:, translation_language: nil)
      sentence = sentence.to_s.split.join(" ")
      translation = translation.to_s.strip
      translation_language ||= Current.translation_language

      validate_custom_input!(sentence:, language:, token_range:, translation:, translation_language:)
      start_index, end_index = custom_span(sentence, token_range)
      raise InputError.new(:selection_required) unless start_index

      transaction do
        phrase = Phrase.create!(user:, l1: language, text_l1: sentence)
        token = phrase.phrase_tokens.create!(
          l1_start_index: start_index,
          l1_end_index: end_index,
          index_type: :character_index
        )
        token.token_translations.create!(language: translation_language, translation:)
        user.phrase_token_users.create!(phrase_token: token, language: translation_language)
      end
    end

    private

    def sources_for(records)
      media_ids = records.filter_map { |record| record.phrase.medium_id }.uniq
      return {} if media_ids.empty?

      Lesson.where(medium_id: media_ids).where.not(course_id: nil)
        .includes(:course).order(:order, :id)
        .each_with_object({}) { |lesson, sources| sources[lesson.medium_id] ||= lesson.course&.name }
    end

    def validate_custom_input!(sentence:, language:, token_range:, translation:, translation_language:)
      raise InvalidInput, "phrase language is missing" if language.blank?
      raise InvalidInput, "translation language is missing" if translation_language.blank?
      raise InputError.new(:sentence_required) if sentence.blank?
      raise InputError.new(:selection_required) if token_range.blank?
      raise InputError.new(:translation_required) if translation.blank?
      raise InvalidInput, "token range is invalid" unless valid_token_range?(sentence, token_range)
    end

    def valid_token_range?(sentence, token_range)
      return false unless token_range.respond_to?(:first) && token_range.respond_to?(:last)

      first_index = token_range.first
      last_index = token_range.last
      first_index.is_a?(Integer) && last_index.is_a?(Integer) &&
        first_index >= 0 && first_index <= last_index && last_index < sentence.split.length
    end

    def custom_span(sentence, token_range)
      words = sentence.split
      first_index = token_range.first
      last_index = token_range.last
      start_offset = first_index.zero? ? 0 : words.first(first_index).join(" ").length + 1
      end_offset = words.first(last_index).join(" ").length + (last_index.zero? ? 0 : 1) + words[last_index].length - 1

      picked = sentence[start_offset..end_offset].to_s
      leading = picked[LEADING_JUNK]&.length.to_i
      trailing = picked[TRAILING_JUNK]&.length.to_i
      return if leading + trailing >= picked.length

      [ start_offset + leading, end_offset - trailing ]
    end
  end

  private

  def span
    return @span if defined?(@span)

    start_index = phrase_token.l1_start_character_index
    end_index = phrase_token.l1_end_character_index
    @span = if start_index.nil? || end_index.nil? || start_index.negative? || end_index >= context.length || start_index > end_index
      nil
    else
      [ start_index, end_index ]
    end
  end

  def pin_available_language
    return if language.present? || phrase_token.nil?

    translations = phrase_token.token_translations.includes(:language).to_a
    preferred = translations.find do |translation|
      translation.language_id == Current.translation_language_id
    end
    self.language = (preferred || translations.first)&.language
  end

  def refresh_review_lesson
    return if user.destroyed?

    language = phrase_token.phrase.l1
    user.refresh_review_lesson!(language)
  end
end
