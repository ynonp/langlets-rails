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

  # Raised by #retry! when the request is in no state to be restarted. Loud on
  # purpose: this is a console tool, and a `false` nobody notices reads exactly
  # like a retry that worked.
  class NotRetryable < StandardError; end

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

  # Restart a failed import. Console/operator tool: the Queue deliberately
  # offers no user-facing retry, and nothing calls this automatically — a failed
  # import has already been settled and refunded, so restarting it is a decision
  # somebody makes after fixing the cause.
  #
  # Four things have to move together, and skipping any one of them leaves a
  # retry that looks like it worked and does nothing:
  #
  #   * the request goes back to `queued`. CreateCourseJob#start_imports! and
  #     Imports::Finalizer#pending_requests both only see active rows, so the
  #     pipeline would run for nobody and the card would stay dead.
  #   * `created_at` moves to now. Imports::Finalizer fails a request whose
  #     record holds an error newer than it, and the previous run's error is
  #     exactly that — a resumed run clears an error only for a step it actually
  #     re-runs, so the entry outlives the retry and would re-fail it within
  #     seconds. `since:` is already how the finalizer tells somebody else's
  #     older failure from its own; this attempt genuinely starts now. The
  #     alternative — deleting the errors from `data` — edits a record shared
  #     with every other import of the same video.
  #   * the course goes back to `pending`. Course#process only claims a pending
  #     course, so CreateCourseJob would log "already processing" and return.
  #   * a new deadline is scheduled. schedule_timeout is an after_create_commit,
  #     so without this the retry has no timeout at all and a second silent
  #     failure spins forever.
  #
  # Credits are deliberately untouched. The failure refunded already, and a
  # retry is us fixing our own import rather than a second sale; `refunded`
  # stays true so a second failure can't mint a free credit in
  # Imports::Settlement#fail!.
  #
  # Returns self, raises NotRetryable if the request can't be restarted.
  def retry!
    raise NotRetryable, "ImportRequest #{id} is #{status}; only a failed import can be retried" unless failed?
    raise NotRetryable, "ImportRequest #{id} has no course to resume" if course.nil?
    raise NotRetryable, "ImportRequest #{id} has no pipeline record to resume" if create_song_progress.nil?

    language = Language.find_by(english_name: translation_language)
    raise NotRetryable, "ImportRequest #{id} wants unknown translation language #{translation_language.inspect}" if language.nil?

    # idx_import_requests_active_dedupe would reject the update anyway; this
    # turns a raw RecordNotUnique into something that says what to do instead.
    if (duplicate = duplicate_active_request)
      raise NotRetryable, "ImportRequest #{duplicate.id} is already importing this video for this user"
    end

    # Asked before we make ourselves active, so the answer is about other people.
    ride_along = covered_by_sibling?

    transaction do
      update!(status: :queued, progress_percent: 0, pipeline_step: nil, failure_reason: nil, created_at: Time.zone.now)

      # Inside the transaction, like Imports::Create: Solid Queue is Postgres-backed,
      # so the job row commits with the change it acts on or not at all.
      schedule_timeout

      unless ride_along
        if course.published?
          # Only this language failed. Knocking a live course back to `pending`
          # would unpublish it for everyone already using it.
          course.course_translations.find_by(language: language)&.pending!
          AddCourseTranslationJob.perform_later(create_song_progress_id, course_id, language.id)
        else
          course.update!(status: :pending)
          CreateCourseJob.perform_later(create_song_progress_id, course_id)
        end
      end
    end

    Rails.logger.info "ImportRequest #{id} retried#{' (riding along on a run already in flight)' if ride_along}"

    self
  end

  private

  def duplicate_active_request
    user.import_requests.active.where.not(id: id).find_by(
      youtube_video_id: youtube_video_id,
      clip_language: clip_language,
      translation_language: translation_language
    )
  end

  # Somebody else's run may already cover this — Imports::Create#join! exists so
  # that two users importing one video share a single pipeline — and a second
  # run against the same CreateSongProgress means two sets of callbacks patching
  # one blob.
  def covered_by_sibling?
    siblings = ImportRequest.active.where(course_id: course_id).where.not(id: id)

    # An unpublished course publishes for everyone at once, and Imports::Finalizer
    # then starts a run for every language still outstanding — ours included.
    return siblings.exists? unless course.published?

    # A published course only ever gains our language from a run started for that
    # language, so only a sibling waiting on the same one covers us.
    siblings.exists?(translation_language: translation_language)
  end

  def schedule_timeout
    ImportRequestTimeoutJob.set(wait: TIMEOUT).perform_later(id)
  end
end
