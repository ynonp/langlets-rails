module Admin
  class PipelineRecordsController < BaseController
    def index
      term = search_term
      scope = CreateSongProgress.select(:id, :youtubeurl, :clip_language, :created_at, :updated_at).order(updated_at: :desc, id: :desc)
      scope = scope.where("youtubeurl ILIKE ?", term) if @query.present?
      # Count separately: PostgreSQL cannot count a multi-column select.
      @records = paginate(scope.unscope(:select)).select(:id, :youtubeurl, :clip_language, :created_at, :updated_at)
    end

    def show
      @record = CreateSongProgress.find(params[:id])
      @runs = paginate(ImportRequest.where(create_song_progress_id: @record.id).includes(:user, :course).order(created_at: :desc, id: :desc))
      @courses = Course.where(create_song_progress_id: @record.id).order(:id)
    end
  end
end
