class ProspectSetupsController < ApplicationController
  skip_before_action :require_authentication_for_native_app
  layout "marketing"
  before_action :load_prospect

  def show
    @account = User.find_by(email: @prospect.email)
  end

  def create
    @prospect.activate!(**params.permit(:password, :password_confirmation).to_h.symbolize_keys)
    redirect_to new_user_session_path, notice: t("marketing.activated"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    @account = User.find_by(email: @prospect.email)
    render :show, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @account = User.find_by(email: @prospect.email)
    @errors = [ t("marketing.retry") ]
    render :show, status: :unprocessable_entity
  end

  private

  def load_prospect
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "strict-origin"
    @prospect = Prospect.find_by_token_for(:setup, params[:token])
    if @prospect.nil? || @prospect.activated_at?
      render :expired, status: :gone
    else
      I18n.locale = @prospect.locale
    end
  end
end
