module Imports
  # UnsupportedLanguage lives in its own file so Zeitwerk can autoload it.

  # Turns "here's a YouTube link" into a queued import — the single entry point
  # for the Add Video sheet, the share extension and the API.
  #
  # Order matters: the video is checked *before* a credit moves, so a private or
  # deleted video costs nothing. Everything after that is one transaction, and
  # the job is enqueued inside it — GoodJob is Postgres-backed, so the job row
  # commits atomically with the request. Enqueuing after commit would leave a
  # charged request that nothing ever picks up if the process died in between.
  class Create
    # :created        — charged a credit, queued the pipeline
    # :deduped        — already published; enrolled, free
    # :joined         — someone else is importing it right now; rides along, free
    # :already_queued — this user already has it in flight; no second charge
    Result = Data.define(:status, :import_request, :course) do
      def created? = status == :created
      def deduped? = status == :deduped
      def joined? = status == :joined
      def already_queued? = status == :already_queued
      def charged? = created?
    end

    def self.call(...) = new(...).call

    def initialize(user:, url:, clip_language:, translation_language:, client_token: nil)
      @user = user
      @url = url
      @clip_language = clip_language
      @translation_language = translation_language
      @client_token = client_token
    end

    # Raises Youtube::Oembed::UnavailableVideo for a bad/private/deleted video,
    # Credits::InsufficientCredits when the balance won't cover it, and
    # UnsupportedLanguage for a language we don't teach. None of them charge.
    def call
      validate_languages!

      # Also the availability check: oEmbed 401/403/404 means we can't import it,
      # and we find that out before taking the credit.
      video = Youtube::Oembed.fetch(url)

      # Already in the Library: hand it over, enrolled and free.
      if (published = published_course_for(video))
        enroll!(published, source: :library)
        return Result.new(status: :deduped, course: published, import_request: nil)
      end

      # This user already asked for it.
      if (mine = active_request_for(video))
        return Result.new(status: :already_queued, import_request: mine, course: mine.course)
      end

      # Someone else is importing it right now. Ride along on their course rather
      # than starting a second pipeline: the work is shared, and two pending
      # courses for one video+pair means whichever publishes second violates
      # idx_courses_published_video_pair and fails an import the user paid for.
      if (in_flight = in_flight_course_for(video))
        return Result.new(status: :joined, import_request: join!(in_flight, video), course: in_flight)
      end

      create_and_charge!(video)
    end

    private

    attr_reader :user, :url, :clip_language, :translation_language, :client_token

    def clip_language_record
      @clip_language_record ||= Language.find_by(english_name: clip_language)
    end

    def translation_language_record
      @translation_language_record ||= Language.find_by(english_name: translation_language)
    end

    def validate_languages!
      raise UnsupportedLanguage, "unknown clip language: #{clip_language.inspect}" if clip_language_record.nil?
      raise UnsupportedLanguage, "unknown translation language: #{translation_language.inspect}" if translation_language_record.nil?
    end

    # The Library's canonical course for this video and pair, if anyone has
    # already made it. Compared on youtube_video_id, never on main_media_url —
    # youtu.be/X and watch?v=X&t=9 are the same video but different strings.
    def published_course_for(video)
      Course.published.find_by(
        youtube_video_id: video.video_id,
        language: clip_language_record,
        translation_language: translation_language_record
      )
    end

    def active_request_for(video)
      user.import_requests.active.find_by(
        youtube_video_id: video.video_id,
        clip_language: clip_language,
        translation_language: translation_language
      )
    end

    # A course for this pair that someone has already started but not published.
    # Deliberately excludes `error` so a previously failed import can be retried.
    def in_flight_course_for(video)
      Course.where(status: [ :pending, :processing ])
            .find_by(
              youtube_video_id: video.video_id,
              language: clip_language_record,
              translation_language: translation_language_record
            )
    end

    # Attach to an import someone else is already paying for. No charge: the
    # pipeline runs once regardless, and CreateCourseJob enrolls every attached
    # user when it publishes.
    def join!(course, video)
      user.import_requests.create!(
        youtube_url: video.canonical_url,
        youtube_video_id: video.video_id,
        clip_language: clip_language,
        translation_language: translation_language,
        title: video.title,
        client_token: client_token,
        course: course,
        create_song_progress: progress_for(video),
        status: :importing,
        charged: false
      )
    end

    def progress_for(video)
      CreateSongProgress.find_by(
        youtubeurl: video.canonical_url,
        clip_language: clip_language,
        translation_language: translation_language
      )
    end

    def enroll!(course, source:)
      enrollment = Enrollment.find_or_initialize_by(user: user, course: course)
      enrollment.source = source if enrollment.new_record?
      enrollment.save!
      enrollment
    rescue ActiveRecord::RecordNotUnique
      Enrollment.find_by!(user: user, course: course)
    end

    def create_and_charge!(video)
      import_request = nil

      ActiveRecord::Base.transaction do
        # Shared across everyone importing this video+pair: the AI work is done
        # once and reused. This is why CreateSongProgress has no user_id.
        progress = CreateSongProgress.find_or_create_by!(
          youtubeurl: video.canonical_url,
          clip_language: clip_language,
          translation_language: translation_language
        ) { |p| p.data = {} }

        course = build_course!(video)

        import_request = user.import_requests.create!(
          youtube_url: video.canonical_url,
          youtube_video_id: video.video_id,
          clip_language: clip_language,
          translation_language: translation_language,
          title: video.title,
          client_token: client_token,
          course: course,
          create_song_progress: progress,
          status: :queued
        )

        # After the request exists so the ledger entry can point at it. Raises
        # InsufficientCredits, which rolls the whole thing back — no orphan
        # request, no orphan course.
        Credits::Ledger.spend!(
          user: user,
          subject: import_request,
          idempotency_key: "import:#{import_request.id}"
        )
        import_request.update!(charged: true)

        # Deliberately not enrolled yet. The course is `pending` and has no
        # lessons; putting it on Home now would show a course you can't open.
        # CreateCourseJob enrolls every attached user once it publishes.
        CreateCourseJob.perform_later(progress.id, course.id)
      end

      Result.new(status: :created, import_request: import_request, course: import_request.course)
    end

    # Course.slug is globally unique and Courses::Naming is deterministic, so the
    # same video imported for a second translation language derives the same slug
    # and collides. Retry with a suffix, the way ImportCourseJob does.
    #
    # Each attempt gets its own savepoint: the slug collision surfaces as either
    # RecordInvalid (the model's slug_uniqueness_with_user_check) or, when two
    # importers race, RecordNotUnique from the index — and a raw Postgres error
    # aborts the enclosing transaction, so retrying without a savepoint would die
    # with "current transaction is aborted".
    def build_course!(video, max_attempts: 10)
      naming = Courses::Naming.call(title: video.title, video_id: video.video_id)

      max_attempts.times do |attempt|
        slug = attempt.zero? ? naming.slug : "#{naming.slug}-#{attempt}"

        begin
          return ActiveRecord::Base.transaction(requires_new: true) do
            Course.create!(
              name: naming.name,
              slug: slug,
              main_media_url: video.canonical_url,
              youtube_video_id: video.video_id,
              language: clip_language_record,
              translation_language: translation_language_record,
              user: user,
              status: :pending
            )
          end
        rescue ActiveRecord::RecordNotUnique
          next
        rescue ActiveRecord::RecordInvalid => e
          # Only a slug clash is worth another attempt; anything else is a real
          # problem and retrying just hides it.
          raise e unless e.record.errors.include?(:slug)

          next
        end
      end

      raise ActiveRecord::RecordInvalid.new(Course.new), "could not find a free slug for #{naming.slug.inspect}"
    end
  end
end
