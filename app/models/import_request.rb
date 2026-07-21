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

  validates :youtube_url, :youtube_video_id, :clip_language, :translation_language, presence: true
  validates :progress_percent, inclusion: { in: 0..100 }

  # What the Queue badge counts, and what the dedupe index covers.
  scope :active, -> { where(status: [ statuses[:queued], statuses[:importing] ]) }
  scope :recent_first, -> { order(created_at: :desc) }

  # Ready imports the user hasn't been shown on Home yet — drives the
  # "JUST IMPORTED" hero card.
  scope :just_imported, -> { ready.where(updated_at: 24.hours.ago..) }

  def active?
    queued? || importing?
  end

  def thumbnail_url
    Medium.youtube_thumbnail_url(youtube_video_id)
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
end
