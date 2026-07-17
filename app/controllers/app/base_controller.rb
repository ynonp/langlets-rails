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
  end
end
