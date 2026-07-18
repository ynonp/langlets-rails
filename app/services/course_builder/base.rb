module CourseBuilder
  class Base
    include WordToCharIndex

    def collect_json_data(progress)
      phrases_map = progress.data["phrases"].group_by { |p| p["id"] }.transform_values(&:first)
      translations_map = progress.data["phrases_with_token_translations"]["phrases"].group_by { |p| p["phrase_id"] }.transform_values { |v| v.first["translations"] }
      data = progress.data
      result = {}
      result[:youtubeurl] = progress.youtubeurl
      result[:clip_language] = progress.clip_language
      result[:translation_language] = progress.translation_language

      result[:lessons] = data["lessons"].map do |lesson|
        {
          order: lesson["order"],
          title: lesson["title"],
          phrases: lesson["phrases"].map do |phrase_data|
            p = phrases_map[phrase_data["id"]]
            {
              id: p["id"],
              text_l1: p["text_l1"],
              text_l2: p["text_l2"],
              timestamp: p["timestamp"],
              translations: (translations_map[phrase_data["id"]] || []).map do |t|
                l1_char_start, l1_char_end = word_indices_to_char_indices(t["clip_indices"], p["text_l1"])
                l2_char_start, l2_char_end = word_indices_to_char_indices(t["translation_indices"], p["text_l2"])
                {
                  translation: t["translation_tokens"].join(" "),
                  l1_index: [ l1_char_start, l1_char_end ],
                  l2_index: l2_char_start ? [ l2_char_start, l2_char_end ] : nil,
                  language_alignment_activity: Random.random_number(2)
                }
              end
            }
          end
        }
      end

      result
    end

    private

    def word_indices_to_char_indices(word_indices, text)
      return [ nil, nil ] if word_indices.nil?

      start_char = word_to_char_index(text, word_indices.first)
      end_char = word_to_char_index(text, word_indices.last, inclusive: true)
      return [ nil, nil ] if start_char.nil? || end_char.nil?

      [ start_char, end_char ]
    end
  end
end
