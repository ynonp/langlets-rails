module App
  # Langlets Pro: the "how to get it" screen and its confirmation.
  #
  # Nothing is purchased here. Pro is granted by hand from the console
  # (User#pro!) after someone reaches out on the Discord this screen links to,
  # so `#show` is the whole flow — there is no server-rendered step after it,
  # only a console action somewhere else and time to wait for it.
  class ProController < BaseController
    # Every Pro CTA in the app links here, so this one guard is what keeps a
    # browser from reaching a screen written for the native shells.
    before_action :require_native_screen

    # Where the screen sends people to ask for Pro.
    DISCORD_INVITE_URL = "https://discord.gg/ADsrTBqYXB".freeze

    def show
      # Already Pro: nothing left to ask for. Send them to the confirmation,
      # which doubles as the "what you have" screen.
      return redirect_to app_pro_success_path if current_user.pro?

      @free_imports_used = current_user.free_imports_used
      @discord_invite_url = DISCORD_INVITE_URL
    end

    def success
      @subscription = current_user.pro_subscription

      # Landing here without an entitlement means nobody has granted it yet.
      # Showing "You're Pro!" then would be a straight lie, so go back to the
      # offer.
      redirect_to app_pro_path if @subscription.nil?
    end

    private

    def require_native_screen
      # An existing subscriber is not being sent to Discord: #show forwards
      # them to #success, which is the "what you have" screen. Someone granted
      # Pro while signed in on one platform should still be able to see it on
      # the other, so only the Discord CTA is gated, not the status.
      return if can_view_pro_screen? || current_user.pro?

      redirect_to app_home_path,
                  alert: t("app.import_requests.new.out_of_credits_web_hint")
    end
  end
end
