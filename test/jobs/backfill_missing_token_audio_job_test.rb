require "test_helper"

class BackfillMissingTokenAudioJobTest < ActiveJob::TestCase
  setup do
    @english = languages(:english)
    @medium = Medium.create!(
      url: "https://www.youtube.com/watch?v=audio-backfill",
      language: @english
    )
    @phrase = Phrase.create!(
      medium: @medium,
      l1: @english,
      text_l1: "old recent attached",
      timestamp: "00:01"
    )
  end

  test "enqueues only missing token audio older than six hours" do
    old_missing = create_token(0, created_at: Time.zone.now - 7.hours)
    create_token(1, created_at: Time.zone.now - 5.hours)
    old_attached = create_token(2, created_at: Time.zone.now - 7.hours)
    attach_audio_metadata(old_attached)
    clear_enqueued_jobs

    assert_enqueued_with(job: GenerateTokenAudioJob, args: [ old_missing.id ]) do
      assert_equal 1, BackfillMissingTokenAudioJob.perform_now
    end
    assert_equal 1, enqueued_jobs.size
  end

  test "is registered to run daily" do
    recurring = YAML.safe_load_file(Rails.root.join("config/recurring.yml"))
    task = recurring.dig("production", "backfill_missing_token_audio")

    assert_equal "BackfillMissingTokenAudioJob", task.fetch("class")
    assert_equal "every day at 5:30am", task.fetch("schedule")
  end

  private

  def create_token(index, created_at:)
    PhraseToken.create!(
      phrase: @phrase,
      l1_start_index: index,
      l1_end_index: index
    ).tap { |token| token.update_column(:created_at, created_at) }
  end

  def attach_audio_metadata(token)
    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.hex(16),
      filename: "existing.wav",
      content_type: "audio/wav",
      service_name: "s3_public",
      byte_size: 5,
      checksum: Digest::MD5.base64digest("audio")
    )
    ActiveStorage::Attachment.create!(name: "l1_audio", record: token, blob:)
  end
end
