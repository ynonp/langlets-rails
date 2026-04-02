module CourseBuilder
  class Base
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
      return [ nil, nil ] if word_indices.nil? || text.nil?

      words = text.split
      start_word = word_indices.first
      end_word = word_indices.last

      return [ nil, nil ] if start_word.nil? || end_word.nil?

      start_char = if start_word == 0
        0
      else
        words[0...start_word].join(" ").length + 1
      end

      end_char = words[0...end_word].join(" ").length + 1 + words[end_word].length - 1

      [ start_char, end_char ]
    end
  end
end
