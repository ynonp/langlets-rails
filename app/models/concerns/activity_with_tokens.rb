module ActivityWithTokens
  extend ActiveSupport::Concern

  def ordered_phrases
    @ordered_phrases ||= phrases
      .ordered_by_timestamp
      .includes(
        token_translations: {
          l1_audio_attachment: :blob,
          phrase: {
            text_l1: { script_variants: :script },
            text_l2: { script_variants: :script }
          }
        },
        text_l1: { script_variants: :script },
        text_l2: { script_variants: :script }
      )
      .to_a
  end
end
