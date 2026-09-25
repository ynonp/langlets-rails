class DailyChallengesController < App::BaseController
  skip_before_action :require_native_app
  layout -> { native_app? ? "app" : "web" }

  def show
    @challenge = current_user.starter_challenge
    @languages = Language.order(:english_name)
    @selected_language_ids = @challenge&.language_ids || []
    @delivery = current_user.notification_delivery
    @current_quest = @challenge&.current_quest
    @practice_started = @challenge&.practice_started?
    @practice_language = @challenge&.practice_language if @practice_started
    @reminder_time = @challenge&.reminder_time || "09:00"
    @reminder_timezone = @challenge&.reminder_timezone || "UTC"
    @timezone_options = ActiveSupport::TimeZone.all.sort_by(&:to_s).map { |zone| [zone.to_s, zone.tzinfo.identifier] }.uniq { |_, id| id }
    @catalog = StarterChallengeCatalog.all if @current_quest
  end

  def ask_for_push?
    native_app? && current_user.push_notifications? && current_user.starter_challenge.present?
  end

  def create
    permitted = params.permit(:reminder_time, :reminder_timezone, language_ids: [], notification_delivery: [])
    StarterChallenge.enroll!(user: current_user, language_ids: permitted[:language_ids],
      delivery: permitted.fetch(:notification_delivery, current_user.notification_delivery),
      reminder_time: permitted[:reminder_time], reminder_timezone: permitted[:reminder_timezone])
    SendDailyChallengesJob.perform_later
    redirect_to daily_challenge_path, status: :see_other
  rescue ArgumentError
    show
    flash.now[:alert] = t("daily_challenge.invalid_selection")
    render :show, status: :unprocessable_entity
  end

  def complete
    quest = current_user.starter_challenge&.daily_challenges&.find_by!(day: params[:day])
    raise ActiveRecord::RecordNotFound unless quest
    quest.complete!
    redirect_to daily_challenge_path, status: :see_other
  rescue ArgumentError
    head :unprocessable_entity
  end
end
