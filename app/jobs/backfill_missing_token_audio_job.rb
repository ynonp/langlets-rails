class BackfillMissingTokenAudioJob < ApplicationJob
  queue_as :default

  MINIMUM_AGE = 6.hours

  def perform
    enqueued_count = 0
    cutoff = Time.zone.now - MINIMUM_AGE

    PhraseToken.missing_l1_audio.where(created_at: ...cutoff).find_each do |token|
      GenerateTokenAudioJob.perform_later(token.id)
      enqueued_count += 1
    end

    Rails.logger.info(
      "BackfillMissingTokenAudioJob enqueued #{enqueued_count} missing token audio jobs"
    )

    enqueued_count
  end
end
