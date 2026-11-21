# Resolves the language the Dictionary translates into, inferring it once for
# users who never chose one:
#
#   1. an explicit choice (Profile, or the Dictionary's own picker);
#   2. otherwise the language most of their saved words are in, falling back to
#      the language of their imported videos — adopted as their choice, so the
#      inference runs once;
#   3. otherwise nil, and the caller asks.
#
# A target equal to the native language is treated as unset: the Dictionary
# would have nothing to translate between.
module DictionaryTargetLanguage
  extend ActiveSupport::Concern

  private

  def dictionary_target_language
    return @dictionary_target_language if defined?(@dictionary_target_language)

    language = current_user.target_language
    if language.nil?
      current_user.adopt_target_language!(current_user.inferred_target_language)
      language = current_user.target_language
    end
    language = nil if language&.id == Current.translation_language_id
    @dictionary_target_language = language
  end

  # Languages the learner can choose to learn: everything except the language
  # the app already speaks to them in.
  def dictionary_target_choices
    Language.where.not(id: Current.translation_language_id).order(:english_name).to_a
  end
end
