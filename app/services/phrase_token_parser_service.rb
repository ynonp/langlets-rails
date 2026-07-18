# Example usage of PhraseTokenParser with Rails models
# This would typically be used in a controller or service

# Example usage:
#
# input_text = <<~TEXT
#   [We were] good, we were gold => [היינו] טובים, היינו זהב
#   We were [good], we were gold => היינו [טובים], היינו זהב
#   We were good, [we were] gold => היינו טובים, [היינו] זהב
# TEXT
#
# parser = PhraseTokenParser.new(input_text)
# parsed_phrases = parser.parse
#
# # Create Phrase and TokenTranslation records
# parsed_phrases.each do |parsed_phrase|
#   # Assuming you have l1 and l2 Language objects and a medium object
#   phrase = Phrase.create!(
#     text_l1: parsed_phrase.l1_text,
#     text_l2: parsed_phrase.l2_text,
#     l1: english_language,
#     l2: hebrew_language,
#     medium: medium,
#     timestamp: "00:00" # or whatever timestamp is appropriate
#   )
#
#   # Create token translations
#   parsed_phrase.token_translations.each do |parsed_token|
#     TokenTranslation.create!(
#       phrase: phrase,
#       l1_start_index: parsed_token.l1_start_index,
#       l1_end_index: parsed_token.l1_end_index,
#       l2_start_index: parsed_token.l2_start_index,
#       l2_end_index: parsed_token.l2_end_index,
#       translation: parsed_token.translation
#     )
#   end
# end

class PhraseTokenParserService
  def self.import_from_text(input_text, l1_language, l2_language, medium, base_timestamp = "00:00")
    parser = PhraseTokenParser.new(input_text)
    parsed_phrases = parser.parse
    created_phrases = []

    parsed_phrases.each_with_index do |parsed_phrase, index|
      # Calculate timestamp (increment by 1 second for each phrase for now)
      timestamp_seconds = parse_timestamp(base_timestamp) + index
      timestamp = Phrase.to_string_timestamp(timestamp_seconds)

      phrase = Phrase.create!(
        text_l1: parsed_phrase.l1_text,
        l1: l1_language,
        medium: medium,
        timestamp: timestamp
      )
      phrase.phrase_translations.create!(language: l2_language, text: parsed_phrase.l2_text)

      # Create token translations
      parsed_phrase.token_translations.each do |parsed_token|
        span = PhraseToken.create!(
          phrase: phrase,
          l1_start_index: parsed_token.l1_start_index,
          l1_end_index: parsed_token.l1_end_index,
          index_type: :character_index
        )
        span.token_translations.create!(
          language: l2_language,
          l2_start_index: parsed_token.l2_start_index,
          l2_end_index: parsed_token.l2_end_index,
          translation: parsed_token.translation
        )
      end

      created_phrases << phrase
    end

    created_phrases
  end

  private

  def self.parse_timestamp(timestamp_str)
    parts = timestamp_str.split(":")
    minutes = parts[0].to_f
    seconds = parts[1].to_f
    minutes * 60 + seconds
  end
end
