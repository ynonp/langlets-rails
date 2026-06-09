class PreferencesController < ApplicationController
  # Persist the chosen color theme. Always stored in a long-lived cookie so the
  # choice survives for logged-out visitors and is available before the user
  # record loads; also written to the user's preferences JSON when signed in.
  def update
    theme = params[:theme]
    theme = User::DEFAULT_THEME unless User::VALID_THEMES.include?(theme)

    cookies.permanent[:theme] = { value: theme, same_site: :lax }
    current_user.update(theme: theme) if user_signed_in?

    respond_to do |format|
      format.json { render json: { theme: theme } }
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
