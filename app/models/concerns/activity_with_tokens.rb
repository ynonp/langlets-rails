module ActivityWithTokens
  extend ActiveSupport::Concern

  def ordered_phrases
    @ordered_phrases ||= phrases
      .ordered_by_timestamp
      .includes(token_translations: { l1_audio_attachment: :blob })      
      .to_a
  end
end
