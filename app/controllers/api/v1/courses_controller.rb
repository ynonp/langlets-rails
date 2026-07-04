module Api
  module V1
    class CoursesController < BaseController
      before_action -> { doorkeeper_authorize! :"courses:read" }

      def index
        if params[:language].blank?
          return render status: :unprocessable_entity,
                        json: { error: "missing_parameter", error_description: "language parameter is required" }
        end

        render json: CoursesQuery.new(
          language: params[:language],
          page: params[:page],
          per_page: params[:per_page],
          base_url: request.base_url
        ).call
      end
    end
  end
end
