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

        # Keep the share-extension API contract synchronous: callers expect the
        # response to report the post-dedupe status and final credit balance.
        # The interactive Add Video form uses the provisional detecting state
        # because it can immediately navigate to a live, polling UI.
        video = VideoSource.fetch(params[:url])
        language, detected_data = CreateSongPipelineHttp.detect_language(url: video.canonical_url)
        result = Imports::Create.call(
          user: current_resource_owner,
          url: video.canonical_url,
          clip_language: language.english_name,
          translation_language: params[:translation_language],
          client_token: params[:client_token],
          detected_data: detected_data
        )

        render_result(result)
      rescue Credits::InsufficientCredits
        # 402 rather than 403: it's a billing state, not a permission problem.
        render status: :payment_required,
               json: { error: "insufficient_credits",
                       error_description: "You're out of credits.",
                       credits_left: 0 }
      rescue VideoSource::UnavailableVideo => e
        render status: :unprocessable_entity,
               json: { error: "unavailable_video", error_description: e.message }
      rescue Imports::UnsupportedLanguage => e
        render status: :unprocessable_entity,
               json: { error: "unsupported_language", error_description: e.message }
      rescue CreateSongPipelineHttp::TriggerError => e
        render status: :unprocessable_entity,
               json: { error: "language_detection_failed", error_description: e.message }
      end

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
