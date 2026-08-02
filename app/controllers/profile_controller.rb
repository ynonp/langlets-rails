# The signed-in user's account page: recent XP, learning language, theme, and
# account deletion.
class ProfileController < ApplicationController
  before_action :authenticate_user!

  XP_CHART_DAYS = 7

  def show
    @xp_series = ActivityLog.daily_xp_series_for_user(current_user, days: XP_CHART_DAYS)
    @total_xp = ActivityLog.total_xp_for_user(current_user)
    @streak = ActivityLog.streak_info_for_user(current_user)

    @languages = Language.all.order(:english_name)
    @current_language = Language.find_by(iso_name: current_language_code)
  end

  # The set of channels to deliver over — any of email and push, including
  # neither. Applies to the notification subsystem only — Devise mail and
  # Channel invitations are answers to something the user just did and are not
  # suppressible from here.
  #
  # `permit(notification_delivery: [])` is what lets the array through at all;
  # the form always submits the key (its hidden field carries the empty case),
  # and User#notification_delivery= drops anything unrecognised.
  def update_notifications
    current_user.notification_delivery =
      params.require(:user).permit(notification_delivery: [])[:notification_delivery]
    current_user.save!

    redirect_to profile_path, notice: t("notifications.preferences.updated")
  end

  private

  # Same shape as OnboardingController#language_redirect_url: switching language
  # is a redirect carrying ?lang=<iso>, which default_url_options then carries
  # onto every link. Pass ApplicationController::ALL_LANGUAGES to clear it.
  def language_redirect_url(iso)
    uri = URI.parse(profile_path)
    query = Rack::Utils.parse_nested_query(uri.query)
    query["lang"] = iso
    uri.query = Rack::Utils.build_nested_query(query).presence
    uri.to_s
  end
  helper_method :language_redirect_url
end
