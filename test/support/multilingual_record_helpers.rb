module MultilingualRecordHelpers
  def build_translated_phrase(attributes = {})
    attributes = attributes.symbolize_keys
    translation_language = attributes.delete(:l2)
    translated_text = attributes.delete(:text_l2)
    translation_language ||= Current.translation_language || languages(:english) if translated_text
    phrase = Phrase.new(attributes)

    return phrase unless translation_language || translated_text

    Current.translation_language ||= translation_language
    phrase.define_singleton_method(:l2) { translation_language }
    phrase.define_singleton_method(:text_l2) { translated_text }
    phrase
  end

  def create_translated_phrase!(attributes = {})
    attributes = attributes.symbolize_keys
    translation_language = attributes.delete(:l2)
    translated_text = attributes.delete(:text_l2)
    phrase = Phrase.create!(attributes)

    if translation_language || translated_text
      raise ArgumentError, "l2 and text_l2 must be provided together" unless translation_language && translated_text

      phrase.phrase_translations.create!(language: translation_language, text: translated_text)
      Current.translation_language ||= translation_language
    end

    phrase
  end

  def create_translated_course!(attributes = {})
    attributes = attributes.symbolize_keys
    translation_language = attributes.delete(:translation_language)
    course = Course.create!(attributes)

    if translation_language
      course.course_translations.create!(
        language: translation_language,
        name: course.name,
        status: :ready
      )
      Current.translation_language ||= translation_language
    end

    course
  end

  def create_translated_token!(attributes = {})
    attributes = attributes.symbolize_keys
    phrase = attributes.delete(:phrase)
    translation = attributes.delete(:translation)
    language = attributes.delete(:language) || phrase.l2 || Current.translation_language
    translation_attributes = attributes.extract!(:l2_start_index, :l2_end_index)

    raise ArgumentError, "translation language is required" unless language

    phrase_token = phrase.phrase_tokens.create!(attributes)
    localized = phrase_token.token_translations.create!(
      translation_attributes.merge(language: language, translation: translation)
    )
    phrase_token.resolved_translation = localized
    Current.translation_language ||= language
    phrase_token
  end
end

ActiveSupport::TestCase.include MultilingualRecordHelpers

module PhraseMultilingualTestAccessors
  def translated_phrase_tokens
    phrase_tokens.to_a.map do |phrase_token|
      TranslatedPhraseTokenTestView.new(phrase_token, phrase_token.token_translations.first)
    end
  end
end

Phrase.include PhraseMultilingualTestAccessors

class TranslatedPhraseTokenTestView
  def initialize(phrase_token, token_translation)
    @phrase_token = phrase_token
    @token_translation = token_translation
  end

  def translation = @token_translation&.translation
  def l2_start_index = @token_translation&.read_attribute(:l2_start_index)
  def l2_end_index = @token_translation&.read_attribute(:l2_end_index)

  def [](attribute)
    return public_send(attribute) if %i[translation l2_start_index l2_end_index].include?(attribute.to_sym)

    @phrase_token[attribute]
  end

  def method_missing(method_name, ...)
    return @phrase_token.public_send(method_name, ...) if @phrase_token.respond_to?(method_name)

    super
  end

  def respond_to_missing?(method_name, include_private = false)
    @phrase_token.respond_to?(method_name, include_private) || super
  end
end
