module ActivityWithTokens
  extend ActiveSupport::Concern

  def ordered_phrases
    @ordered_phrases ||= phrases
      .ordered_by_timestamp
      .includes(token_translations: { l1_audio_attachment: :blob })
      .to_a
  end

  def phrases_with_calculated_end_timestamps
    @processed_phrases ||= begin
      all_medium_phrases = lesson.medium.phrases.ordered_by_timestamp.to_a
      Phrase.with_calculated_end_timestamps(ordered_phrases, all_medium_phrases)
    end
  end
end
