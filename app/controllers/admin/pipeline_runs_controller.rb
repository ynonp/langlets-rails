module Admin
  class PipelineRunsController < BaseController
    def index
      term = search_term
      scope = ImportRequest.includes(:user, :course).order(created_at: :desc, id: :desc)
      @status = params[:status].to_s
      scope = scope.where(status: @status) if ImportRequest.statuses.key?(@status)
      scope = scope.joins(:user).where("users.email ILIKE ? OR import_requests.youtube_url ILIKE ? OR import_requests.failure_reason ILIKE ?", term, term, term) if @query.present?
      @runs = paginate(scope)
    end

    def show
      @run = ImportRequest.includes(:user, :course, :create_song_progress).find(params[:id])
    end

    def retry
      run = ImportRequest.find(params[:id])
      # Serialize clicks across requests sharing a pipeline, then reload the
      # request so a replay cannot enqueue another attempt from stale state.
      if run.create_song_progress
        run.create_song_progress.with_lock { run.with_lock { run.retry! } }
      else
        run.with_lock { run.retry! }
      end
      redirect_to admin_pipeline_run_path(run), notice: "Import queued for retry. Completed pipeline steps will be reused.", status: :see_other
    rescue ImportRequest::NotRetryable, ActiveRecord::RecordNotUnique => error
      redirect_to admin_pipeline_run_path(run), alert: error.is_a?(ImportRequest::NotRetryable) ? error.message : "An active import already exists for this video.", status: :see_other
    end
  end
end
