module Activities
  class LanguageAlignmentActivity < Activity
    def activity_params
      selected_tokens = phrase_tokens
        .joins(:phrase)
        .order("phrases.timestamp ASC")
        .includes(
          :localized_translation,
          { l1_audio_attachment: :blob },
          phrase: [ :l1, :localized_translation, :phrase_translations ]
        )
        .to_a
      first_phrase = selected_tokens.first&.phrase

      {
        **video_params,
        rtl: first_phrase&.l1&.rtl,
        phrases_with_tokens: selected_tokens.group_by(&:phrase).map do |phrase, tokens|
          {
            phrase: phrase,
            tokens: tokens.map do |token|
              {
                l1_start_index: token.l1_start_index,
                l1_end_index: token.l1_end_index,
                l2_start_index: token.l2_start_index,
                l2_end_index: token.l2_end_index,
                audio_url: token.l1_audio_url
              }
            end
          }
        end,
        l1: first_phrase&.l1&.english_name,
        l2: first_phrase&.l2&.english_name
      }
    end

    def video_params
      first_timestamp = phrases.reorder(timestamp: :asc).pick(:timestamp)
      last_timestamp = phrases.reorder(timestamp: :desc).pick(:timestamp)
      media_url = lesson.attributes["media_url"] || lesson.medium.url

      {
        video_id: Medium.new(url: media_url).extract_youtube_video_id,
        start_timestamp: first_timestamp,
        end_timestamp: lesson.end_timestamp || to_string_timestamp(Phrase.timestamp_to_seconds(last_timestamp) + 5)
      }
    end
  end
end
