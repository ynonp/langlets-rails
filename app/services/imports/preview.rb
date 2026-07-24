module Imports
  # Read-only counterpart to Imports::Create: works out what tapping Approve
  # *would* do, without moving a credit or writing a row.
  #
  # The Add Video sheet has to answer three questions before it can draw the
  # approval controls — is this video real, does the user already have it, and
  # what will it cost — and it has to answer them the same way Create will a
  # moment later. So the checks here are deliberately the same checks in the same
  # order (§4: duplicate before balance), reading the same columns. When Create's
  # dedupe rules change, these have to change with them or the sheet starts
  # lying: promising "1 credit" for something that turns out to be free, or
  # offering Approve for a video already in the Library.
  class Preview
    # :in_library — published and readable now; enrolling is free
    # :in_queue   — already importing, either this user's request or someone
    #               else's course this user would ride along on
    # :importable — nothing exists yet; cost says what Approve will charge
    Result = Data.define(:status, :video, :course, :import_request, :cost) do
      def in_library? = status == :in_library
      def in_queue? = status == :in_queue
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
      validate_languages!

      video = VideoSource.fetch(url)

      # §4: duplicates short-circuit before the balance is ever consulted, so a
      # video the user already owns can't trigger the insufficient-credits state.
      if (published = published_course_for(video))
        # Published but not yet translated into their language still costs a
        # credit — Create#create_translation_and_charge! runs the pipeline again
        # for the new pair. Only a course they can actually open today is free.
        if published.translation_ready?(translation_language_record)
          return result(:in_library, video, course: published, cost: 0)
        end

        return result(:importable, video, course: published, cost: 1)
      end

      if (mine = active_request_for(video))
        return result(:in_queue, video, course: mine.course, import_request: mine, cost: 0)
      end

      # Someone else is mid-import. Create joins their course for free, so quote
      # free — the alternative is a button that says "use 1 credit" and then
      # doesn't, which breaks the promise that cost is visible before it's spent.
      if (in_flight = in_flight_course_for(video))
        return result(:importable, video, course: in_flight, cost: 0)
      end

      result(:importable, video, cost: 1)
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
