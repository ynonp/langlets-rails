module App
  # Base for the langlets. mobile app screens (Home / Library / Queue / sheets).
  #
  # Namespaced App:: rather than Native:: because these are plain server-rendered
  # screens — a future Android shell would reuse them unchanged.
  class BaseController < ApplicationController
    layout "app"

    before_action :authenticate_user!
    before_action :require_native_app
    before_action :set_queue_badge_count

    private

    # Gate on the user-agent check, and on the 2.x builds specifically: these
    # screens have no navigation of their own — the tab bar is the native
    # UITabBarController that only 2.x draws — so a 1.x build landing here
    # would be stranded. 1.x keeps the web UI at root. Note this is
    # presentation only: it's UA sniffing and trivially spoofed, so nothing
    # here may authorise a credit spend on the strength of it. Imports::Create
    # does its own checking.
    #
    # The ?native=1 escape hatch exists because otherwise every CSS tweak needs
    # the simulator, and these screens will be iterated on a lot. It only ever
    # relaxes which layout you see, never what you're allowed to do.
    def require_native_app
      return if native_tabs_app?
      return if native_preview?

      redirect_to root_path
    end

    def native_preview?
      session[:native_preview] = true if params[:native] == "1"
      session.delete(:native_preview) if params[:native] == "0"

      session[:native_preview].present? && !Rails.env.production?
    end

    # The Queue tab's badge — active imports, on every screen.
    def set_queue_badge_count
      @queue_badge_count = current_user.import_requests.active.count
    end

    # Whether the app should put up the iOS notification prompt on this page load.
    #
    # Not at launch. iOS gives you exactly one chance at that prompt per install —
    # a "Don't Allow" is effectively permanent, and asking before the app has done
    # anything for the user is the way to earn one. So we wait until they have an
    # import in flight or finished: at that point "we'll tell you when it's ready"
    # is an obvious trade rather than a cold call.
    #
    # It's only a hint. The native side still checks the real authorization status
    # and stays silent unless it's genuinely undetermined, so a user who already
    # decided is never asked twice.
    helper_method :ask_for_push?
    def ask_for_push?
      return false unless native_tabs_app?

      current_user.import_requests.where(status: [ :queued, :importing, :ready ]).exists?
    end
  end
end
