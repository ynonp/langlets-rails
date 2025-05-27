class Phrase < ApplicationRecord
  belongs_to :medium
  belongs_to :l1, class_name: :Language
  belongs_to :l2, class_name: :Language
  has_many :token_translations, dependent: :destroy
  has_timestamp [:timestamp]

  default_scope { order(timestamp: :asc) }

  scope :between_durations, ->(from, to) {
  where(
    "(split_part(timestamp, ':', 1)::int * 60 + split_part(timestamp, ':', 2)::int) BETWEEN ? AND ?",
    from, to
  )
  }

  def add_token_translation(text, text_index, translation, translation_index, **attributes)
    text_re = Regexp.new("\\b#{Regexp.escape(text.downcase)}\\b")
    l1_start_index = text_l1.downcase.nth_index(text_re, text_index)
    if l1_start_index.nil?
      pp text_re
      puts "Couldn't find text #{text} starting from index #{text_index} in phrase #{text_l1}"
    end

    l1_end_index = l1_start_index + text.length

    translation_re = Regexp.new("\\b#{Regexp.escape(translation.downcase)}\\b")
    l2_start_index = text_l2.downcase.nth_index(translation_re, translation_index) unless translation_index < 0
    l2_end_index = l2_start_index + translation.length unless l2_start_index.nil?

    TokenTranslation.create!(
      phrase: self,
      l1_start_index:,
      l1_end_index:,
      l2_start_index:,
      l2_end_index:,
      translation:,
      **attributes
    )
  end

  def find_token_translation(text, text_index=0)
    l1_start_index = text_l1.downcase.nth_index(text.downcase, text_index)
    l1_end_index = l1_start_index + text.length
    result = self.token_translations.find_by(l1_start_index:, l1_end_index:)
    if result.nil?
      pp l1_start_index, text, text_l1, text_index, l1_end_index, id
      pp self.token_translations.to_a
    end
    result
  end

  def create_mappings
    tokens = Ai::Gemini.extract_keywords_from_phrases(
      text_l1,
      text_l2,
      l1.english_name,
      l2.english_name)

    tokens.map do |token|
      start_index = token["l1_index"].to_i
      token_text = token["l1_text"]
      token_translation = token["l2_text"]
      token_questions = token["l1_questions"]
      end_index = start_index + token_text.length

      l2_start_index = token["l2_index"].to_i
      l2_end_index = l2_start_index + token_translation.length

      extracted = text_l1[start_index...end_index]
      next if extracted != token_text

      code = <<END
      TokenTranslation.find_or_create_by(
        phrase: phrase,
        l1_start_index: #{start_index},
        l1_end_index: #{end_index}
      ) do |token|
        token.questions = #{(token_questions || []).to_s}
        token.translation = "#{token_translation}"
        token.l2_start_index = #{l2_start_index}
        token.l2_end_index = #{l2_end_index}
      end
END
      puts code
      code
    end
  end
end
