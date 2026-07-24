# A user's request to turn a video into a course — the row behind one card on the
# Queue screen.
#
# See the migration for why this is separate from CreateSongProgress (the shared
# pipeline cache) and Course (the shared output).
class ImportRequest < ApplicationRecord
  belongs_to :user
  belongs_to :course, optional: true
  belongs_to :create_song_progress, optional: true

  enum :status, {
    queued: 0,
    importing: 1,
    ready: 2,
    failed: 3,
    canceled: 4
  }

  # Wall-clock, from the moment the user asked. Nothing in the import path
  # blocks any more — the worker triggers the pipeline and leaves, and the run
  # reports back through PipelineCallbacksController — so this is the single
  # deadline the whole flow has, and the reason a request cannot get stuck.
  TIMEOUT = 10.minutes

  validates :youtube_url, :youtube_video_id, :clip_language, :translation_language, presence: true
  validates :progress_percent, inclusion: { in: 0..100 }

  # On the model rather than in Imports::Create because there are four ways to
  # end up with a request (charge, join, translation, admin) and the guarantee
  # is only worth anything if it holds for all of them. after_create_commit so
  # the row is visible to the worker that eventually picks the job up.
  after_create_commit :schedule_timeout

  # What the Queue badge counts, and what the dedupe index covers.
  scope :active, -> { where(status: [ statuses[:queued], statuses[:importing] ]) }
  scope :recent_first, -> { order(created_at: :desc) }

  # Ready imports the user hasn't been shown on Home yet — drives the
  # "JUST IMPORTED" hero card.
  scope :just_imported, -> { ready.where(updated_at: 24.hours.ago..) }

  def active?
    queued? || importing?
  end

  # The course is created in the same transaction as the request and carries the
  # cover oEmbed gave us, so ask it first — that's the only place a TikTok
  # thumbnail exists. The derivation is the fallback for YouTube, where it costs
  # nothing, and for the brief window before a course is attached.
  def thumbnail_url
    course&.thumbnail_url.presence || VideoSource.derived_thumbnail_url(youtube_url)
  end

  # The Queue shows a percent for importing items only; a queued item hasn't
  # started and a ready one is done.
  def display_percent
    return 100 if ready?
    return 0 unless importing?

    progress_percent
  end

  # "Transcribing · step 1 of 6" for the Queue card. Read from the denormalised
  # column, never derived here: see the migration for why.
  #
  # Rows that predate the column, and ones whose pipeline hasn't reported a stage
  # yet, fall back to the percentage the card showed before — less informative,
  # but still true, and better than a card that says only "Importing".
  def stage_label
    pipeline_step.presence || "Importing · #{display_percent}%"
  end

  private

  def schedule_timeout
    ImportRequestTimeoutJob.set(wait: TIMEOUT).perform_later(id)
  end
end
