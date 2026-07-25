class GuestImportRequestsController < ApplicationController
  PENDING_VIDEO_COOKIE = :pending_video_url
  PENDING_IMPORT_COOKIE = :pending_import_request

  def create
    raw_url = params[:url].to_s.strip

    # The homepage "Start For Free" button carries no link: guests are not asked
    # for a video before they have an account. It only marks that the signup
    # started from "Create Your Own", so the first authentication lands on Add
    # Video instead of the homepage.
    if raw_url.blank?
      store_pending(PENDING_IMPORT_COOKIE, "1", 1.day)
      return redirect_to new_user_registration_path
    end

    video_url = VideoSource.loose_canonical(raw_url)

    if video_url.blank?
      return redirect_to root_path, alert: "That doesn't look like a video link. Paste a YouTube or TikTok link."
    end

    store_pending(PENDING_VIDEO_COOKIE, video_url, 30.minutes)

    redirect_to new_user_registration_path
  end

  private

  def store_pending(name, value, ttl)
    cookies.encrypted[name] = {
      value: value,
      expires: Time.zone.now + ttl,
      httponly: true,
      same_site: :lax
    }
  end
end
