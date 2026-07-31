module App
  # Screens 03 (Queue) and 04 (Add a video).
  class ImportRequestsController < BaseController
    # Queue and Add Video are shared by the native and web apps. The rest of
    # the /app surface remains native-only through App::BaseController.
    skip_before_action :require_native_app
    layout :import_requests_layout

    def index
      if web_request?
        return redirect_to new_app_import_request_path
      end

      prepare_new_import
      render :new
    end

    def new
      prepare_new_import
      if web_view?
        @paypal_client = Paypal::Client.new
        @credit_pack = Paypal::CreditPacks.fetch("standard")
      end

      render "app/import_requests/web/new" if web_view?
    end

    # Everything below the input in the Add Video sheet: empty state, preview
    # card, duplicate notices, errors. The add-video Stimulus controller reloads
    # this frame as the user types and the server decides which state to draw —
    # the client deliberately does not classify the input itself, because then
    # the two could disagree about what counts as a video id. Charges nothing;
    # the credit only moves in #create.
    #
    # Three outcomes, because this sheet only accepts links. Anything that isn't
    # one is a mistake worth naming, not a query worth running.
    def resolve
      @query = params[:q].to_s.strip
      @translation_language = default_translation_language

      # Blank goes back to the empty state, not to an error the user hasn't
      # earned yet — they've typed nothing wrong, they've typed nothing at all.
      if @query.blank?
        @mode = :empty
      elsif !VideoSource.importable?(@query)
        # A watch link, youtu.be, /shorts/, a bare 11-character id, or a TikTok
        # post or share link. The Stimulus controller holds anything else back
        # until typing stops, so this branch doesn't fire on the way to a valid
        # link. Note this asks importable? rather than for an id: a TikTok share
        # link has no id in it until oEmbed resolves one.
        @mode = :error
        @error = "That doesn't look like a video link. Paste a YouTube or TikTok link, or a YouTube video ID."
      else
        @mode = :preview
        @preview = Imports::Preview.call(
          user: current_user,
          url: VideoSource.loose_canonical(@query),
          clip_language: nil,
          translation_language: @translation_language.english_name
        )
      end

      render "app/import_requests/web/resolve" if web_view?
    rescue VideoSource::UnavailableVideo
      # A well-formed id that YouTube won't serve. Distinct from the message
      # above on purpose: "you typed it wrong" and "this video is gone" send the
      # user to two different next moves.
      @mode = :error
      @error = "We couldn't read that video. It may be private, age-restricted or deleted."
      render "app/import_requests/web/resolve" if web_view?
    rescue Imports::UnsupportedLanguage
      @mode = :error
      @error = "We don't teach that language yet."
      render "app/import_requests/web/resolve" if web_view?
    end

    def create
      result = Imports::Create.call(
        user: current_user,
        url: params[:url],
        translation_language: Current.translation_language&.english_name || params[:translation_language],
        client_token: params[:client_token].presence
      )

      redirect_to_result(result)
    rescue Credits::InsufficientCredits
      # Checked in #new too; this is for the race, not the common path.
      redirect_to app_credits_path
    rescue VideoSource::UnavailableVideo
      redirect_to new_app_import_request_path(url: params[:url]),
                  alert: "We couldn't read that video. It may be private, age-restricted or deleted."
    rescue Imports::UnsupportedLanguage
      redirect_to new_app_import_request_path(url: params[:url]),
                  alert: "We don't teach that language yet."
    rescue CreateSongPipelineHttp::TriggerError
      redirect_to new_app_import_request_path(url: params[:url]),
                  alert: "We couldn't detect the video's language."
    end

    # Cancelling a queued import refunds the credit. Deleting a failed or ready
    # item just removes it from the queue — failed items were already refunded,
    # and ready items have a published course the user can still access.
    #
    # Responds with a Turbo Stream so the client can optimistically remove the
    # card and the server response corrects the page if anything went wrong.
    def destroy
      import_request = current_user.import_requests.find(params[:id])

      if import_request.queued?
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
      elsif import_request.failed? || import_request.ready?
        import_request.destroy!
      else
        # importing — can't be removed; re-render the queue so the optimistic
        # removal on the client is corrected.
      end

      respond_to do |format|
        format.turbo_stream do
          @import_requests = current_user.import_requests.recent_first.includes(:course).limit(50)
          active_count = @import_requests.count(&:active?)
          template = web_request? ? "app/import_requests/web/queue_update" : "app/import_requests/queue_update"
          render template, locals: { active_count: active_count }
        end
        format.html { redirect_to app_import_requests_path }
      end
    end

    # Re-import something that failed. It was refunded when it failed, so this
    # charges again like any other import. The old failed request is removed —
    # the retried item replaces it.
    def retry
      failed = current_user.import_requests.find(params[:id])
      return redirect_to app_import_requests_path unless failed.failed?

      result = Imports::Create.call(
        user: current_user,
        url: failed.youtube_url,
        clip_language: failed.clip_language,
        translation_language: failed.translation_language
      )

      # The new request replaces the failed one — remove the old card from the
      # queue so the user doesn't see both.
      failed.destroy!

      redirect_to_result(result)
    rescue Credits::InsufficientCredits
      redirect_to app_credits_path
    rescue VideoSource::UnavailableVideo, Imports::UnsupportedLanguage
      redirect_to app_import_requests_path, alert: "That video still can't be imported."
    end

    private

    def import_requests_layout
      web_view? ? "application" : "app"
    end

    def web_view?
      web_request? && action_name.in?(%w[index new resolve])
    end

    def web_request?
      !native_app?
    end

    def redirect_to_result(result)
      if result.deduped?
        redirect_to course_path(result.course),
                    notice: "Already in the Library — added to your Home, no credit used."
      else
        redirect_to gallery_path(imports: "pending")
      end
    end

    def prepare_new_import
      @import_request = ImportRequest.new
      @translation_language = default_translation_language
    end

    # Best guess at what they read. Not stored per-user yet.
    def default_translation_language
      Language.find_by(english_name: "English")
    end
  end
end
