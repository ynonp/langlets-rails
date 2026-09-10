class TryController < ApplicationController
  def show
    @video_url = VideoSource.loose_canonical(params[:url].to_s.strip)
    raise VideoSource::UnavailableVideo if @video_url.blank?

    @video = Imports::VideoPreflight.call(@video_url).video
    @video_info = TryVideoInfo.for(@video)
  rescue Imports::VideoPreflight::TooLong => error
    redirect_to(native_app? ? onboarding_video_path : root_path,
                alert: I18n.t("imports.errors.too_long", count: error.maximum_minutes))
  rescue VideoSource::UnavailableVideo
    redirect_to(native_app? ? onboarding_video_path : root_path,
                alert: I18n.t("imports.errors.unavailable"))
  end
end
