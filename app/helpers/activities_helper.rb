module ActivitiesHelper
  def timestamp_to_seconds(timestamp_mm_ss)
    minutes, seconds = timestamp_mm_ss.split(":").map(&:to_i)
    (minutes * 60) + seconds
  end

  def wrap_tokens_in_spans(phrase, attributes_map)
    texts = phrase.token_translations.order(l1_start_index: :asc).to_a.inject([]) do |acc, val|
      next_translated_token = {"l1" => phrase.text_l1[val.l1_start_index...val.l1_end_index], "l2" => val.translation, "last_index" => val.l1_end_index}
      if acc.empty?
        if val.l1_start_index.zero?
          [*acc, next_translated_token]
        else
          [
            *acc,
            {"l1" => phrase.text_l1[0...val.l1_start_index], "last_index" => val.l1_start_index},
            next_translated_token
          ]
        end
      elsif acc[-1]["last_index"] == val.l1_start_index
        [*acc, next_translated_token]
      else
        [
          *acc,
          {"l1" => phrase.text_l1[acc[-1]["last_index"]...val.l1_start_index], "last_index" => val.l1_start_index},
          next_translated_token
        ]
      end
    end

    safe_join(texts.map do |val|
      content_tag(:span, val["l1"], {**attributes_map, data: { translation: val["l2"] } })
    end)
  end
end
