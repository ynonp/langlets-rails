module Api
  module V1
    class VocabularyController < BaseController
      before_action -> { doorkeeper_authorize! :"vocabulary:read" }

      def index
        render json: VocabularyQuery.new(
          user: current_resource_owner,
          language: params[:language],
          page: params[:page],
          per_page: params[:per_page]
        ).call
      end
    end
  end
end
