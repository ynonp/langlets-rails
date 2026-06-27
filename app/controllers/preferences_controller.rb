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

  # Persist the watch-video activity toggles (translation / karaoke) into the
  # signed-in user's preferences JSON. No-op for logged-out visitors.
  def watch_video
    if user_signed_in?
      current_user.watch_video_preferences = params.permit(:translation, :karaoke)
      current_user.save
    end

    prefs = current_user&.watch_video_preferences || User::WATCH_VIDEO_DEFAULTS
    render json: { watch_video: prefs }
  end
end
