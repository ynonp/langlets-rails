class OnboardingController < ApplicationController
  layout "onboarding"

  skip_before_action :require_authentication_for_native_app, only: [ :welcome, :beta, :video, :language, :save_language ]
  before_action :redirect_web_browsers, only: [ :welcome, :beta, :video, :language, :save_language ]

  def welcome
  end

  def beta
    redirect_to onboarding_language_path unless User.beta_pro?
  end

  def video
    @homepage_videos = HomepageVideos.for_page
  end

  def language
    return redirect_to daily_challenge_path if user_signed_in?
    @languages = Language.order(:english_name)
    @selected_language_ids = session[:starter_language_ids] || []
    @delivery = session[:starter_delivery] || ["push"]
    @reminder_time = session[:starter_reminder_time] || "09:00"
    @reminder_timezone = session[:starter_reminder_timezone] || "UTC"
    @timezone_options = ActiveSupport::TimeZone.all.sort_by(&:to_s).map { |zone| [zone.to_s, zone.tzinfo.identifier] }.uniq { |_, id| id }
  end

  def save_language
    return redirect_to daily_challenge_path if user_signed_in?
    ids = Array(params[:language_ids]).reject(&:blank?).map(&:to_s).uniq
    languages = Language.where(id: ids)
    begin
      _minute, timezone = StarterChallenge.parse_reminder!(time: params[:reminder_time], timezone: params[:reminder_timezone])
    rescue ArgumentError
      timezone = nil
    end
    if ids.empty? || languages.pluck(:id).map(&:to_s).sort != ids.sort || timezone.nil?
      flash.now[:alert] = t("daily_challenge.invalid_selection")
      language
      return render :language, status: :unprocessable_entity
    end
    session[:starter_language_ids] = languages.pluck(:id)
    session[:starter_delivery] = User::NOTIFICATION_DELIVERIES & Array(params[:notification_delivery])
    session[:starter_reminder_time] = params[:reminder_time]
    session[:starter_reminder_timezone] = timezone
    redirect_to onboarding_video_path, status: :see_other
  end

  def redirect_web_browsers
    return if native_app?
    redirect_to root_path
  end
end
