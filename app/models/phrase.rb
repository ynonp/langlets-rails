class Phrase < ApplicationRecord
  belongs_to :medium
  belongs_to :l1, class_name: :Language
  belongs_to :l2, class_name: :Language
  has_many :token_translations, dependent: :destroy
  has_timestamp [:timestamp]

  scope :between_durations, ->(from, to) {
  where(
    "(split_part(timestamp, ':', 1)::int * 60 + split_part(timestamp, ':', 2)::int) BETWEEN ? AND ?",
    from, to
  )
  }

  def create_mappings
    tokens = Ai::Gemini.extract_keywords_from_phrases(
      text_l1,
      text_l2,
      l1.english_name,
      l2.english_name)

    tokens.each do |token|
      start_index = token["l1_index"].to_i
      token_text = token["l1_text"]
      token_translation = token["l2_text"]
      token_questions = token["l1_questions"]
      end_index = start_index + token_text.length

      l2_start_index = token["l2_index"].to_i
      l2_end_index = l2_start_index + token_translation.length

      extracted = text_l1[start_index...end_index]
      next if extracted != token_text

      TokenTranslation.find_or_create_by(
        phrase: self,
        l1_start_index: start_index,
        l1_end_index: end_index
      ) do |token|
        token.questions = token_questions
        token.translation = token_translation
        token.l2_start_index = l2_start_index
        token.l2_end_index = l2_end_index
      end
    end
  end
end
