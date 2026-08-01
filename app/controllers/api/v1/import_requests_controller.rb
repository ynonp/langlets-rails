module Api
  module V1
    # Turning a video into a course over the API. This is what the iOS share
    # extension talks to: an extension runs in its own process and cannot read the
    # host app's WKWebsiteDataStore cookies, so it authenticates with a Doorkeeper
    # bearer token rather than the web session.
    class ImportRequestsController < BaseController
      before_action -> { doorkeeper_authorize! :"imports:read", :"imports:write" }, only: [ :index ]
      before_action -> { doorkeeper_authorize! :"imports:write" }, only: [ :create ]

      def index
        requests = current_resource_owner.import_requests.recent_first.limit(50)

        render json: { import_requests: requests.map { |r| serialize(r) } }
      end

      def create
        return render_missing(:url) if params[:url].blank?
        return render_missing(:translation_language) if params[:translation_language].blank?

        if params[:client_token].present? &&
           (existing = current_resource_owner.import_requests.find_by(client_token: params[:client_token]))
          return render status: :ok,
                        json: serialize(existing).merge(credits_left: credits_left)
        end

        # Deliberately the same provisional `detecting` path the Add Video form
        # uses. This used to detect the language inline so the response could
        # report a post-dedupe status and the final credit balance — but
        # detection is a pipeline round trip that downloads and analyses the
        # video, and the share sheet sat on it for ~10 seconds with a spinner.
        # Nothing the extension does with the answer is worth that: it dismisses
        # itself the moment the POST is handed off, and the Queue and the push
        # notification are what actually report the outcome. What is left here
        # is one oEmbed call inside Imports::Create, which is also the
        # availability check.
        result = Imports::Create.call(
          user: current_resource_owner,
          url: params[:url],
          translation_language: params[:translation_language],
          client_token: params[:client_token]
        )

        render_result(result)
      rescue Credits::InsufficientCredits
        # 402 rather than 403: it's a billing state, not a permission problem.
        # The description names Pro because credits cannot be topped up — the
        # share extension has no paywall of its own, so the sentence has to say
        # where the way forward is.
        render status: :payment_required,
               json: { error: "insufficient_credits",
                       error_description: "You're out of free imports. Open Langlets to subscribe to Pro.",
                       credits_left: 0 }
      rescue VideoSource::UnavailableVideo => e
        render status: :unprocessable_entity,
               json: { error: "unavailable_video", error_description: e.message }
      rescue Imports::UnsupportedLanguage => e
        render status: :unprocessable_entity,
               json: { error: "unsupported_language", error_description: e.message }
      end
      # No language_detection_failed here any more: detection runs in
      # DetectImportLanguageJob, so a video we can't place lands as a failed
      # card in the Queue rather than as a status code nobody is waiting for.

      private

      def render_result(result)
        if result.paused?
          # Nothing happened and there is no request to poll. The share
          # extension cannot present a paywall, so say plainly why it stopped.
          render status: :payment_required,
                 json: { status: "paused",
                         error: "This is in your paused Langlets Pro library. Resubscribe in the app to open it.",
                         credits_left: credits_left }
        elsif result.in_channel?
          # Nothing to wait for: the course already existed, so it is in their
          # channel and ready to practise right now. There is no queue item to
          # poll, which is why this doesn't serialize an import request.
          render status: :ok,
                 json: { status: "ready",
                         course: serialize_course(result.course),
                         credits_left: credits_left }
        else
          render status: result.created? ? :created : :ok,
                 json: serialize(result.import_request).merge(credits_left: credits_left)
        end
      end

      def credits_left
        current_resource_owner.reload.credit_balance
      end

      def serialize(import_request)
        {
          id: import_request.id,
          status: import_request.status,
          title: import_request.title,
          youtube_video_id: import_request.youtube_video_id,
          thumbnail_url: import_request.thumbnail_url,
          progress_percent: import_request.display_percent,
          failure_reason: import_request.failure_reason,
          course: import_request.course&.published? ? serialize_course(import_request.course) : nil,
          created_at: import_request.created_at.iso8601
        }
      end

      def serialize_course(course)
        return nil if course.nil?

        {
          slug: course.slug,
          name: course.name,
          url: course_url(course, host: request.base_url),
          lessons_count: course.lessons.count
        }
      end

      def render_missing(param)
        render status: :unprocessable_entity,
               json: { error: "missing_parameter", error_description: "#{param} is required" }
      end
    end
  end
end
