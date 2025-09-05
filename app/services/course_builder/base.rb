module CourseBuilder
  class Base
    def collect_json_data(progress)
      phrases_map = progress.data["phrases"].group_by {|p| p["id"] }.transform_values(&:first)
      translations_map = progress.data["phrases_with_token_translations"]["phrases"].group_by {|p| p["phrase_id"] }.transform_values {|v| v.first["translations"] }
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
                {
                  translation: t["translation_tokens"].join(" "),
                  l1_index: t["clip_indices"],
                  l2_index: t["translation_indices"],
                  language_alignment_activity: Random.random_number(2)
                }
              end
            }
          end
        }
      end

      result
    end


  end
end

