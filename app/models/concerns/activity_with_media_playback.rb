module ActivityWithMediaPlayback
  extend ActiveSupport::Concern

  def ordered_phrases
    @ordered_phrases ||= phrases_with_playback_boundaries
  end

  def phrases_with_playback_boundaries
    @phrases_with_playback_boundaries ||= playback_medium
      .phrases_with_playback_boundaries(phrase_ids: phrases.ids)
  end

  private

  def playback_medium
    lesson.medium || raise(ActiveRecord::RecordNotFound, "Media playback activity requires a medium")
  end
end
