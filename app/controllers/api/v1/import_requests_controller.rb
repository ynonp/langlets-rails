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
        return render_missing(:clip_language) if params[:clip_language].blank?
        return render_missing(:translation_language) if params[:translation_language].blank?

        result = Imports::Create.call(
          user: current_resource_owner,
          url: params[:url],
          clip_language: params[:clip_language],
          translation_language: params[:translation_language],
          client_token: params[:client_token]
        )

        render_result(result)
      rescue Credits::InsufficientCredits
        # 402 rather than 403: it's a billing state, not a permission problem.
        # There is no purchase flow yet, so the client can only report it.
        render status: :payment_required,
               json: { error: "insufficient_credits",
                       error_description: "You're out of credits.",
                       credits_left: 0 }
      rescue Youtube::Oembed::UnavailableVideo => e
        render status: :unprocessable_entity,
               json: { error: "unavailable_video", error_description: e.message }
      rescue Imports::UnsupportedLanguage => e
        render status: :unprocessable_entity,
               json: { error: "unsupported_language", error_description: e.message }
      end

      private

      def render_result(result)
        if result.deduped?
          # Already in the Library. Nothing was charged and the course is ready
          # to practise right now.
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
