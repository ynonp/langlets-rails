module Imports
  # Read-only counterpart to Imports::Create: works out what tapping Approve
  # *would* do, without moving a credit or writing a row.
  #
  # The Add Video sheet has to answer three questions before it can draw the
  # approval controls — is this video real, does the user already have it, and
  # what will it cost — and it has to answer them the same way Create will a
  # moment later. So the checks here are deliberately the same checks in the same
  # order (§4: duplicate before balance), reading the same columns, and the price
  # comes from the one place that charges it, Imports::Pricing. When Create's
  # dedupe rules change, these have to change with them or the sheet starts
  # lying: promising "1 credit" for something that turns out to be free, or
  # offering Approve for a video already in the Library.
  class Preview
    # :in_library — already published in this user's own channel and readable in
    #               the language they asked for. The only free duplicate: there
    #               is nothing left to publish.
    # :in_queue   — this user already has a request in flight for it
    # :paused     — theirs, but sitting in a Pro library their subscription no
    #               longer lends them. Resubscribing is the only way back in.
    # :importable — Approve will publish it into their channel; cost says what
    #               that costs. A course somebody else already built is
    #               `:importable` too — it still has to be published into this
    #               user's channel, and that is what a credit buys.
    Result = Data.define(:status, :video, :course, :import_request, :cost) do
      def in_library? = status == :in_library
      def in_queue? = status == :in_queue
      def paused? = status == :paused
      def importable? = status == :importable
      def free? = cost.zero?
    end

    def self.call(...) = new(...).call

    def initialize(user:, url:, clip_language:, translation_language:)
      @user = user
      @url = url
      @clip_language = clip_language
      @translation_language = translation_language
    end

    # Raises VideoSource::UnavailableVideo for a private, deleted or
    # malformed video, and UnsupportedLanguage for a language we don't teach —
    # the sheet renders both as an inline error in place of the preview card
    # rather than as a failed search (§2).
    def call
      validate_languages! if clip_language.present?

      video = VideoSource.fetch(url)

      # Detection is the first paid pipeline action, never preview work. Before
      # it runs we can still recognize a request for this same video already in
      # flight, but cannot truthfully claim which language-specific course it
      # will match.
      if clip_language.blank?
        published = Course.published
                          .joins(:course_translations)
                          .where(youtube_video_id: video.video_id,
                                 course_translations: {
                                   language_id: translation_language_record.id,
                                   status: CourseTranslation.statuses[:ready]
                                 })
                          .first
        if published
          return result(:in_library, video, course: published, cost: 0) if already_published?(published)

          return result(:importable, video, course: published, cost: cost_for(published))
        end

        mine = user.import_requests.active.find_by(
          youtube_video_id: video.video_id,
          translation_language: translation_language
        )
        return result(:in_queue, video, course: mine.course, import_request: mine, cost: 0) if mine

        return result(:importable, video, cost: cost_for)
      end

      # §4: duplicates short-circuit before the balance is ever consulted, so a
      # video the user already has can't trigger the insufficient-credits state.
      if (published = published_course_for(video))
        # Their own import, in a Pro library that has stopped lending it back.
        # Without this the sheet would say "already in your library" and offer an
        # Open button that 404s — the two questions "is it published?" and "can
        # this user read it?" had the same answer for your own imports until the
        # library became revocable.
        return result(:paused, video, course: published, cost: 0) if paused_for_user?(published)

        # Already in their channel and ready to open: nothing to publish, nothing
        # to charge, and the useful button is Open rather than Approve. Anything
        # else about a published course — including one that only needs their
        # language adding — is a publication into their channel and is quoted as
        # one, which is what `cost_for` works out.
        if already_published?(published) && published.translation_ready?(translation_language_record)
          return result(:in_library, video, course: published, cost: 0)
        end

        return result(:importable, video, course: published, cost: cost_for(published))
      end

      if (mine = active_request_for(video))
        return result(:in_queue, video, course: mine.course, import_request: mine, cost: 0)
      end

      # Someone else is mid-import. Create joins their run rather than starting a
      # rival one, but joining is not a discount: the rider's own copy still has
      # to be published into their channel, so it is quoted like any other import.
      if (in_flight = in_flight_course_for(video))
        return result(:importable, video, course: in_flight, cost: cost_for(in_flight))
      end

      result(:importable, video, cost: cost_for)
    end

    private

    attr_reader :user, :url, :clip_language, :translation_language

    def result(status, video, course: nil, import_request: nil, cost: 1)
      Result.new(status: status, video: video, course: course,
                 import_request: import_request, cost: cost)
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
    end

    def published_course_for(video)
      Course.published.find_by(youtube_video_id: video.video_id, language: clip_language_record)
    end

    # Deliberately narrow: only a course sitting in *this user's own* Pro
    # library. A published course they cannot read for some other reason (say,
    # somebody else's private Channel) is a separate, pre-existing case and is
    # left exactly as it was rather than quietly folded in here.
    def paused_for_user?(course)
      Paused.for?(user: user, course: course)
    end

    # Both from Imports::Pricing, so the number on the button is the number
    # Channel#publish! will take.
    def cost_for(course = nil)
      Pricing.cost_for(user: user, course: course)
    end

    def already_published?(course)
      Pricing.already_published?(user: user, course: course)
    end

    def active_request_for(video)
      user.import_requests.active.find_by(
        youtube_video_id: video.video_id,
        clip_language: clip_language,
        translation_language: translation_language
      )
    end

    def in_flight_course_for(video)
      Course.where(status: [ :pending, :processing ])
            .find_by(youtube_video_id: video.video_id, language: clip_language_record)
    end
  end
end
