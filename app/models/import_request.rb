# A user's request to turn a video into a course — the row behind one card on the
# Queue screen.
#
# See the migration for why this is separate from CreateSongProgress (the shared
# pipeline cache) and Course (the shared output).
class ImportRequest < ApplicationRecord
  belongs_to :user
  belongs_to :course, optional: true
  belongs_to :create_song_progress, optional: true
  has_many :evaluation_signups, foreign_key: :admin_import_request_id, dependent: :restrict_with_exception

  enum :status, {
    queued: 0,
    importing: 1,
    ready: 2,
    failed: 3,
    canceled: 4,
    detecting: 5
  }

  # The one failure the user can do something about: the course was built, but
  # their balance no longer covered publishing it into their channel. Stored in
  # `failure_reason`, which is read by people — the Queue renders it and the
  # share extension gets it straight out of the API — so it must never carry
  # Credits::Ledger's own message, which names an internal user id.
  INSUFFICIENT_CREDITS = "Insufficient credits".freeze

  # Raised by #retry! when the request is in no state to be restarted. Loud on
  # purpose: this is a console tool, and a `false` nobody notices reads exactly
  # like a retry that worked.
  class NotRetryable < StandardError; end
  class ArtifactsNotDestroyable < StandardError; end

  # Wall-clock, from the moment the user asked. Nothing in the import path
  # blocks any more — the worker triggers the pipeline and leaves, and the run
  # reports back through PipelineCallbacksController — so this is the single
  # deadline the whole flow has, and the reason a request cannot get stuck.
  TIMEOUT = 10.minutes

  validates :youtube_url, :youtube_video_id, :translation_language, presence: true
  validates :clip_language, presence: true, if: -> { queued? || importing? || ready? }
  validates :progress_percent, inclusion: { in: 0..100 }
  validate :translation_language_differs_from_clip_language

  # On the model rather than in Imports::Create because there are four ways to
  # end up with a request (charge, join, translation, admin) and the guarantee
  # is only worth anything if it holds for all of them. after_create_commit so
  # the row is visible to the worker that eventually picks the job up.
  after_create_commit :schedule_timeout

  # What the Queue badge counts, and what the dedupe index covers.
  scope :active, -> { where(status: [ statuses[:detecting], statuses[:queued], statuses[:importing] ]) }
  scope :recent_first, -> { order(created_at: :desc) }

  # Ready imports the user hasn't been shown on Home yet — drives the
  # "JUST IMPORTED" hero card.
  scope :just_imported, -> { ready.where(updated_at: 24.hours.ago..) }

  def active?
    detecting? || queued? || importing?
  end

  # Whether this failed for want of credits rather than for a technical reason.
  # The Queue's ordinary failure copy promises that a human is reviewing the
  # import, which is true of a pipeline error and false of this one — nobody is
  # coming, and buying credits is the fix.
  def insufficient_credits?
    failed? && failure_reason == INSUFFICIENT_CREDITS
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

  # "Transcribing · step 1 of 7" for the Queue card. Read from the denormalised
  # column, never derived here: see the migration for why.
  #
  # Rows that predate the column, and ones whose pipeline hasn't reported a stage
  # yet, fall back to the percentage the card showed before — less informative,
  # but still true, and better than a card that says only "Importing".
  def stage_label
    return I18n.t("app.import_requests.status.detecting") if detecting?

    if pipeline_step.present?
      label, position, total = pipeline_step.match(/\A(.+) · step (\d+) of (\d+)\z/)&.captures
      step = CreateSong::ProgressReporting::STEP_LABELS.key(label)
      return I18n.t("app.import_requests.status.steps.#{step}", position: position, total: total) if step

      return pipeline_step
    end

    I18n.t("app.import_requests.status.importing", percent: display_percent)
  end

  # Restart a failed import. Console/operator tool: the Queue deliberately
  # offers no user-facing retry, and nothing calls this automatically —
  # restarting is a decision somebody makes after fixing the cause.
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
  # Credits do not enter into it at all. Nothing is charged until the course is
  # published into the user's channel (Channel#publish!), so a failed import took
  # nothing, a retry is not a second sale, and the retried run pays exactly once
  # if it succeeds — the ledger key is the (channel, course) pair, so however
  # many times an operator restarts this, the user buys the course once.
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
          CreateCourseJob.perform_later(create_song_progress_id, course_id, language.id)
        end
      end
    end

    Rails.logger.info "ImportRequest #{id} retried#{' (riding along on a run already in flight)' if ride_along}"

    self
  end

  # Permanently remove this request and the import graph that belongs only to
  # it. This is an operator tool, not the Queue's ordinary delete action:
  # courses and pipeline caches are normally shared by several requests, and
  # deleting either while another import uses it would remove another user's
  # content.
  #
  # The checks and deletes are one transaction so a rejected cleanup leaves the
  # complete graph intact. Active imports are rejected because pipeline jobs and
  # callbacks may still be writing to their progress and course records.
  def destroy_with_artifacts!
    transaction do
      lock!
      raise ArtifactsNotDestroyable, "ImportRequest #{id} is still active" if active?

      artifact_course = course
      artifact_progress = create_song_progress
      artifact_media = if artifact_course
        artifact_course.lessons.where.not(medium_id: nil).distinct.map(&:medium).compact
      else
        []
      end

      ensure_artifacts_are_exclusive!(artifact_course, artifact_progress, artifact_media)

      destroy!
      artifact_course&.destroy!
      artifact_media.each(&:destroy!)
      artifact_progress&.destroy!
    end
  end

  private

  def translation_language_differs_from_clip_language
    return if clip_language.blank? || translation_language.blank?
    return unless clip_language == translation_language

    errors.add(:translation_language, "must differ from clip language")
  end

  def ensure_artifacts_are_exclusive!(artifact_course, artifact_progress, artifact_media)
    if artifact_course && ImportRequest.where(course_id: artifact_course.id).where.not(id: id).exists?
      raise ArtifactsNotDestroyable, "Course #{artifact_course.id} is shared by another ImportRequest"
    end

    if artifact_progress
      if ImportRequest.where(create_song_progress_id: artifact_progress.id).where.not(id: id).exists?
        raise ArtifactsNotDestroyable, "CreateSongProgress #{artifact_progress.id} is shared by another ImportRequest"
      end

      if Course.where(create_song_progress_id: artifact_progress.id).where.not(id: artifact_course&.id).exists?
        raise ArtifactsNotDestroyable, "CreateSongProgress #{artifact_progress.id} is shared by another Course"
      end
    end

    artifact_media.each do |medium|
      if medium.lessons.where.not(course_id: artifact_course.id).exists?
        raise ArtifactsNotDestroyable, "Medium #{medium.id} is shared by another Course"
      end
    end
  end

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
