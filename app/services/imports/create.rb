module Imports
  # UnsupportedLanguage lives in its own file so Zeitwerk can autoload it.

  # Turns "here's a video link" into either a provisional language-detection
  # request or, when the source language is known, a course published into the
  # user's channel — building it first if nobody has built it yet.
  #
  # This service decides **what has to happen** — build it, join a run already
  # under way, or simply publish something that already exists. It deliberately
  # does not decide what any of that costs. `Channel#publish!` charges, once, for
  # the publication every one of these paths ends in, so the price cannot depend
  # on which path was taken (see Imports::Pricing).
  #
  # Order matters: the video is checked before anything else happens, so a
  # private or deleted video costs nothing and leaves nothing behind. Everything
  # after that is one transaction, and the job is enqueued inside it — Solid Queue
  # is Postgres-backed, so the job row commits atomically with the request.
  # Enqueuing after commit would leave a request nothing ever picks up if the
  # process died in between.
  class Create
    # :created        — queued the pipeline; charged when it publishes
    # :adopted        — the course already existed and was ready, so there was
    #                   nothing to build: published into this user's channel on
    #                   the spot, and charged for it there
    # :deduped        — already in this user's own channel and ready. Nothing
    #                   left to publish, so nothing to charge
    # :joined         — someone else is importing it right now; rides along on
    #                   their run rather than starting a rival one, and pays for
    #                   its own publication when the run lands
    # :already_queued — this user already has it in flight; one publication, one
    #                   charge
    # :paused         — theirs, in a Pro library their subscription no longer
    #                   lends them. Nothing charged, nothing enrolled; the only
    #                   way back in is to resubscribe.
    #
    # `cost` is what this import will take from the user's balance, in total,
    # whenever it is that the course reaches their channel. Zero on Pro, zero for
    # something they already have, and zero for a request that only re-found work
    # they had already paid for.
    Result = Data.define(:status, :import_request, :course, :cost) do
      def created? = status == :created
      def adopted? = status == :adopted
      def deduped? = status == :deduped
      def joined? = status == :joined
      def already_queued? = status == :already_queued
      def paused? = status == :paused

      # The course is in the user's channel now — it either just got published
      # there or already was. The two terminal "here's your course" states.
      def in_channel? = adopted? || deduped?

      def charged? = cost.positive?
    end

    def self.call(...) = new(...).call

    def initialize(user:, url:, translation_language:, clip_language: nil, client_token: nil,
                   detected_data: nil, existing_request: nil, guest_started: false)
      @user = user
      @url = url
      @clip_language = clip_language
      @translation_language = translation_language
      @client_token = client_token
      @detected_data = detected_data
      @existing_request = existing_request
      @guest_started = guest_started
    end

    # Raises VideoSource::UnavailableVideo for a bad/private/deleted video,
    # Credits::InsufficientCredits when the balance won't cover it, and
    # UnsupportedLanguage for a language we don't teach. None of them charge.
    def call
      # A share extension may retry after losing the HTTP response. Replaying
      # its stable UUID must return the original request even if the job moved
      # beyond the active states in the meantime.
      if existing_request.nil? && client_token.present? && (existing = user.import_requests.find_by(client_token: client_token))
        return already_queued(existing, existing.course)
      end

      validate_translation_language!

      # Also the availability check: oEmbed 401/403/404 means we can't import it,
      # and we find that out before anything else happens. For a TikTok share
      # link this is additionally what resolves vt.tiktok.com/... into a post id —
      # nothing downstream can work without it.
      video = VideoSource.fetch(url)
      return create_detection_request!(video) if clip_language.blank?

      validate_languages!

      # Resolve the shared L1 skeleton first, then its per-language readiness.
      if (published = published_course_for(video))
        # Their own import, in a Pro library that has stopped lending it back.
        # Enrolling here would put a course on their Home that 404s when opened,
        # so stop and let the caller offer the one thing that actually helps.
        if Paused.for?(user: user, course: published)
          return Result.new(status: :paused, course: published, import_request: nil, cost: 0)
        end

        # Asked before any work is committed. A request of their own still in
        # flight is already going to publish this course into their channel and
        # be charged for it there; a second request would be a second publication
        # of the same thing, and idx_import_requests_active_dedupe would reject
        # the row anyway.
        if (mine = active_request_for(video))
          return already_queued(mine, mine.course || published)
        end

        return adopt!(published, video) if published.translation_ready?(translation_language_record)

        return create_translation!(published, video)
      end

      # This user already asked for it.
      if (mine = active_request_for(video))
        return already_queued(mine, mine.course)
      end

      # Someone else is importing it right now. Ride along on their course rather
      # than starting a second pipeline: the work is shared, and two pending
      # courses for one video+pair means whichever publishes second violates
      # idx_courses_published_video_pair and fails an import the user paid for.
      #
      # Sharing the run does not make the import free. The rider still ends up
      # with the course published in their own channel, and that publication is
      # the thing a credit buys.
      if (in_flight = in_flight_course_for(video))
        return Result.new(status: :joined, import_request: join!(in_flight, video),
                          course: in_flight, cost: cost_for(in_flight))
      end

      create_and_queue!(video)
    end

    private

    attr_reader :user, :url, :clip_language, :translation_language, :client_token, :existing_request,
                :guest_started

    # What this import will cost when it publishes — asked of the course it will
    # actually publish, so every branch quotes the number the sheet quoted and
    # Channel#publish! goes on to take.
    def cost_for(course = nil)
      Pricing.cost_for(user: user, course: course)
    end

    # Finding work the user already has in flight settles nothing and buys
    # nothing: the request that is already there carries the charge.
    def already_queued(import_request, course)
      Result.new(status: :already_queued, import_request: import_request, course: course, cost: 0)
    end

    def clip_language_record
      @clip_language_record ||= Language.find_by(english_name: clip_language)
    end

    def translation_language_record
      @translation_language_record ||= Language.find_by(english_name: translation_language)
    end

    def validate_languages!
      raise UnsupportedLanguage, "unknown clip language: #{clip_language.inspect}" if clip_language_record.nil?
      raise UnsupportedLanguage, "unknown translation language: #{translation_language.inspect}" if translation_language_record.nil?
      raise UnsupportedLanguage, "the video language must differ from the translation language" if clip_language_record == translation_language_record
    end

    def validate_translation_language!
      raise UnsupportedLanguage, "unknown translation language: #{translation_language.inspect}" if translation_language_record.nil?
    end

    # Detection is free — nothing is published by it — but it is the front door
    # to an import, so refuse it here rather than ten minutes later when the
    # language is known and the user has been watching a progress bar.
    def create_detection_request!(video)
      Pricing.ensure_affordable!(user, cost: cost_for) unless guest_started

      request = nil

      ActiveRecord::Base.transaction do
        progress = CreateSongProgress.create!(
          youtubeurl: video.canonical_url,
          clip_language: nil,
          data: {}
        )
        course = build_course!(video) if guest_started
        course&.update!(create_song_progress: progress)
        request = user.import_requests.create!(
          youtube_url: video.canonical_url,
          youtube_video_id: video.video_id,
          clip_language: nil,
          translation_language: translation_language,
          title: video.title,
          client_token: client_token,
          course: course,
          create_song_progress: progress,
          status: :detecting,
          guest_started: guest_started
        )
        DetectImportLanguageJob.perform_later(request.id)
      end

      Result.new(status: :created, import_request: request, course: nil, cost: cost_for)
    rescue ActiveRecord::RecordNotUnique
      existing = user.import_requests.find_by(client_token: client_token) if client_token.present?
      existing ||= user.import_requests.active.find_by!(
          youtube_video_id: video.video_id,
          translation_language: translation_language
        )
      already_queued(existing, existing.course)
    end

    # The Library's canonical course for this video and pair, if anyone has
    # already made it. Prefer the provider id so youtu.be/X and watch?v=X&t=9
    # are the same video. Older courses predate that column, however, so fall
    # back to their canonical stored URL rather than rebuilding known content.
    def published_course_for(video)
      relation = Course.published.where(language: clip_language_record)
      relation.find_by(youtube_video_id: video.video_id) ||
        relation.find_by(main_media_url: video.canonical_url)
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
            )
    end

    # Attach to an import somebody else already started. The pipeline runs once
    # regardless — that is the point — but the rider is buying what the first
    # importer bought: this course, published into their own channel, which
    # Imports::Settlement does for each of them when the run lands.
    def join!(course, video)
      Pricing.ensure_affordable!(user, cost: cost_for(course), excluding: existing_request&.id)

      persist_request!(
        youtube_url: video.canonical_url,
        youtube_video_id: video.video_id,
        clip_language: clip_language,
        translation_language: translation_language,
        title: video.title,
        client_token: client_token,
        course: course,
        create_song_progress: progress_for(video),
        status: :importing
      )
    end

    def progress_for(video)
      CreateSongProgress.find_by(
        youtubeurl: video.canonical_url,
        clip_language: clip_language,
      )&.tap(&:assert_current_data_format!)
    end

    def enroll!(course, source: :imported)
      enrollment = Enrollment.find_or_initialize_by(user: user, course: course)
      enrollment.source = source if enrollment.new_record?
      enrollment.save!
      enrollment
    rescue ActiveRecord::RecordNotUnique
      Enrollment.find_by!(user: user, course: course)
    end

    # The course already exists and is ready in the language they asked for, so
    # there is nothing to build — only a publication to make. It ends up costing
    # exactly what building it would have, because the credit buys the course in
    # your channel and not the pipeline run (see Channel#publish!).
    #
    # The request is written straight to `ready`: there is nothing to wait for,
    # and an active row would sit under idx_import_requests_active_dedupe for a
    # course that is already finished. It exists at all so the Queue can show what
    # happened and so the ordinary settlement path — enroll, publish, mark ready —
    # is the one that runs here too.
    def adopt!(course, video)
      if guest_started
        import_request = persist_request!(
          youtube_url: video.canonical_url,
          youtube_video_id: video.video_id,
          clip_language: clip_language,
          translation_language: translation_language,
          title: video.title,
          client_token: client_token,
          course: course,
          create_song_progress: course.create_song_progress || existing_request&.create_song_progress,
          status: :ready,
          progress_percent: 100,
          guest_started: true
        )
        Settlement.complete!(import_request, notify: false)
        return Result.new(status: :adopted, course: course, import_request: import_request, cost: 0)
      end

      if Pricing.already_published?(user: user, course: course)
        # Nothing left to publish, so nothing to charge. Enrolling is still worth
        # doing: the channel holds the publication and the enrollment is what puts
        # it on Home, and the two come apart if the user ever removed it there.
        enroll!(course)
        settle_existing_request!(course)
        return Result.new(status: :deduped, course: course, import_request: existing_request, cost: 0)
      end

      # Read before publishing, not after: the publication is what makes this
      # course theirs, so asking afterwards would always answer "already yours,
      # free" and the Result would understate what just happened.
      price = cost_for(course)
      Pricing.ensure_affordable!(user, cost: price, excluding: existing_request&.id)

      import_request = nil

      ActiveRecord::Base.transaction do
        import_request = persist_request!(
          youtube_url: video.canonical_url,
          youtube_video_id: video.video_id,
          clip_language: clip_language,
          translation_language: translation_language,
          title: video.title,
          client_token: client_token,
          course: course,
          # A promotion from detection arrives with a provisional record of its
          # own; keep it rather than nulling the column when the published course
          # predates CreateSongProgress.
          create_song_progress: course.create_song_progress || existing_request&.create_song_progress,
          status: :ready,
          progress_percent: 100
        )

        # Publishes into their channel and charges for it. No push: the user is
        # looking at the app right now, and "your course is ready" for something
        # that was ready before they asked is noise.
        Settlement.complete!(import_request, notify: false)
      end

      Result.new(status: :adopted, course: course, import_request: import_request, cost: price)
    end

    # A detection request that turns out to want a course the user already has.
    # Closing it out beats destroying it: the Queue card becomes the ready course
    # instead of vanishing, and a dangling `detecting` row would otherwise be
    # failed by its own timeout ten minutes later.
    def settle_existing_request!(course)
      return if existing_request.nil?

      existing_request.update!(
        status: :ready,
        clip_language: clip_language,
        course: course,
        progress_percent: 100,
        failure_reason: nil
      )
    end

    def create_and_queue!(video)
      Pricing.ensure_affordable!(user, cost: cost_for, excluding: existing_request&.id) unless guest_started

      import_request = nil

      ActiveRecord::Base.transaction do
        # Shared across everyone importing this video+pair: the AI work is done
        # once and reused. This is why CreateSongProgress has no user_id.
        progress = CreateSongProgress.find_or_create_by!(
          youtubeurl: video.canonical_url,
          clip_language: clip_language,
        ) do |p|
          p.data = @detected_data || {}
        end
        # A found row may predate the multi-language format; fail here, before
        # any work is queued, rather than inside the pipeline.
        progress.assert_current_data_format!

        course = if guest_started && existing_request&.course&.language_id.nil?
          existing_request.course.tap { |provisional| provisional.update!(language: clip_language_record) }
        else
          build_course!(video)
        end
        course.update!(create_song_progress: progress)

        import_request = persist_request!(
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

        # Deliberately not enrolled or published yet. The course is `pending` and
        # has no lessons; putting it on Home now would show a course you can't
        # open, and publishing it would charge for one. Imports::Settlement does
        # both once it is real.
        CreateCourseJob.perform_later(progress.id, course.id, translation_language_record.id)
      end

      Result.new(status: :created, import_request: import_request,
                 course: import_request.course, cost: cost_for)
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
              # Only worth storing when it can't be derived from the URL later.
              # YouTube covers derive for free, so leaving those NULL keeps the
              # column meaningful and matches every pre-existing row.
              thumbnail_url: (video.thumbnail_url unless video.youtube?),
              language: clip_language_record,
              user: user,
              status: :pending
            ).tap do |course|
              course.course_translations.create!(
                language: translation_language_record,
                name: naming.name,
                status: :pending
              )
            end
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

    # The course exists but not in the language they asked for, so the pipeline
    # runs again for that one language and settles like any other import.
    #
    # For somebody who already has this course in their channel that lands as a
    # free second language: the run publishes nothing new, so Channel#publish!
    # finds its ChannelItem already there and takes nothing. That is the design
    # working, not a hole in it — the credit bought the course, and a course that
    # gains a language is still the one course they bought.
    def create_translation!(course, video)
      Pricing.ensure_affordable!(user, cost: cost_for(course), excluding: existing_request&.id)

      import_request = nil
      ActiveRecord::Base.transaction do
        progress = course.create_song_progress || CreateSongProgress.find_or_create_by!(
          youtubeurl: video.canonical_url,
          clip_language: clip_language
        ) do |row|
          row.data = {}
        end
        progress.assert_current_data_format!
        course.update!(create_song_progress: progress) unless course.create_song_progress_id
        course.course_translations.find_or_create_by!(language: translation_language_record) do |translation|
          translation.name = course.name
          translation.status = :pending
        end
        import_request = persist_request!(
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
        AddCourseTranslationJob.perform_later(progress.id, course.id, translation_language_record.id)
      end
      Result.new(status: :created, import_request: import_request, course: course, cost: cost_for(course))
    end

    def persist_request!(**attributes)
      if existing_request
        existing_request.update!(attributes)
        existing_request
      else
        user.import_requests.create!(attributes)
      end
    end
  end
end
