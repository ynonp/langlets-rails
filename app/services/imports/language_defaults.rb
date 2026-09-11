module Imports
  class LanguageDefaults
    SAME_LANGUAGE_TRANSLATIONS = {
      "English" => "Hebrew",
      "Hebrew" => "English",
      "Spanish" => "English"
    }.freeze

    def self.translation_language(clip_language:, translation_language:)
      return translation_language unless clip_language == translation_language

      SAME_LANGUAGE_TRANSLATIONS.fetch(clip_language, translation_language)
    end
  end
end
