# The signed-in user's account page: recent XP, theme, and account deletion.
class ProfileController < ApplicationController
  before_action :authenticate_user!

  XP_CHART_DAYS = 7

  def show
    @xp_series = ActivityLog.daily_xp_series_for_user(current_user, days: XP_CHART_DAYS)
    @total_xp = ActivityLog.total_xp_for_user(current_user)
    @streak = ActivityLog.streak_info_for_user(current_user)
  end

  def update_native_language
    language = Language.where(iso_name: User::NATIVE_LANGUAGE_CODES)
      .find_by(iso_name: params.dig(:user, :native_language))
    if language.nil?
      redirect_to profile_path, alert: t("profile.native_language.invalid")
      return
    end

    current_user.native_language = language
    current_user.save!

    redirect_to profile_path,
      notice: I18n.t("profile.native_language.updated", locale: language.iso_name)
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
end
