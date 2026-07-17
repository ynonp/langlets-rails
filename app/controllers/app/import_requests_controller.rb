module App
  # Screens 03 (Queue) and 04 (Add a video).
  class ImportRequestsController < BaseController
    def index
      @import_requests = current_user.import_requests.recent_first.includes(:course).limit(50)
    end

    def new
      @import_request = ImportRequest.new
      @clip_language = default_clip_language
      @translation_language = default_translation_language
      @languages = Language.order(:english_name)
    end

    def create
      result = Imports::Create.call(
        user: current_user,
        url: params[:url],
        clip_language: params[:clip_language],
        translation_language: params[:translation_language],
        client_token: params[:client_token].presence
      )

      redirect_to_result(result)
    rescue Credits::InsufficientCredits
      # Checked in #new too; this is for the race, not the common path.
      redirect_to app_credits_path
    rescue Youtube::Oembed::UnavailableVideo
      redirect_to new_app_import_request_path(url: params[:url]),
                  alert: "We couldn't read that video. It may be private, age-restricted or deleted."
    rescue Imports::UnsupportedLanguage
      redirect_to new_app_import_request_path(url: params[:url]),
                  alert: "We don't teach that language yet."
    end

    # Cancelling a queued import. The credit goes back — nothing has been spent
    # on it yet in any sense the user cares about.
    def destroy
      import_request = current_user.import_requests.find(params[:id])

      unless import_request.queued?
        return redirect_to app_import_requests_path,
                           alert: "That import has already started."
      end

      ActiveRecord::Base.transaction do
        if import_request.charged? && !import_request.refunded?
          Credits::Ledger.refund!(
            user: current_user,
            subject: import_request,
            idempotency_key: "refund:#{import_request.id}"
          )
          import_request.refunded = true
        end
        import_request.status = :canceled
        import_request.save!
      end

      redirect_to app_import_requests_path, notice: "Import cancelled — your credit is back."
    end

    # Re-import something that failed. It was refunded when it failed, so this
    # charges again like any other import.
    def retry
      failed = current_user.import_requests.find(params[:id])
      return redirect_to app_import_requests_path unless failed.failed?

      result = Imports::Create.call(
        user: current_user,
        url: failed.youtube_url,
        clip_language: failed.clip_language,
        translation_language: failed.translation_language
      )

      redirect_to_result(result)
    rescue Credits::InsufficientCredits
      redirect_to app_credits_path
    rescue Youtube::Oembed::UnavailableVideo, Imports::UnsupportedLanguage
      redirect_to app_import_requests_path, alert: "That video still can't be imported."
    end

    private

    def redirect_to_result(result)
      if result.deduped?
        redirect_to course_path(result.course),
                    notice: "Already in the Library — added to your Home, no credit used."
      else
        redirect_to app_import_requests_path
      end
    end

    # The language they're learning is the one they're importing *from* — it's
    # why they're importing it.
    def default_clip_language
      Language.find_by(iso_name: current_language_code) || Language.find_by(english_name: "Spanish")
    end

    # Best guess at what they read. Not stored per-user yet.
    def default_translation_language
      Language.find_by(english_name: "English")
    end
  end
end
