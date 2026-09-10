class GuestImportRequestsController < ApplicationController
  PENDING_VIDEO_COOKIE = :pending_video_url
  EVALUATION_SIGNUP_COOKIE = :evaluation_signup_token

  def create
    raw_url = params[:url].to_s.strip
    video_url = VideoSource.loose_canonical(raw_url)

    if video_url.blank?
      return redirect_to(native_app? ? onboarding_video_path : root_path,
                         alert: I18n.t("imports.errors.invalid_link"))
    end

    # `/try` already performed this check before rendering the signup buttons,
    # but the POST is public and must remain safe when called directly. Use the
    # resolved provider id here too, which also dedupes TikTok short links.
    preflight = Imports::VideoPreflight.call(video_url)
    video_url = preflight.video.canonical_url

    admin = User.find_by!(email: User::ADMIN_EMAIL)
    translation_language = Current.translation_language.english_name
    clip_language = HomepageVideos.find_by_url(video_url)&.clip_language
    source_video_id = preflight.video.video_id
    source = if source_video_id.present?
      admin.import_requests
           .where(guest_started: true, youtube_video_id: source_video_id, translation_language: translation_language)
           .where(status: [ :detecting, :queued, :importing, :ready ])
           .recent_first
           .first
    end
    source ||= Imports::Create.call(
      user: admin,
      url: video_url,
      clip_language: clip_language,
      translation_language: translation_language,
      guest_started: true
    ).import_request
    evaluation_signup = EvaluationSignup.create!(
      admin_import_request: source,
      initial_course: source.course,
      course: source.course,
      video_url: source.youtube_url,
      video_id: source.youtube_video_id,
      provider: VideoSource.provider(source.youtube_url),
      title: source.title,
      thumbnail_url: source.thumbnail_url,
      clip_language: source.clip_language || clip_language,
      translation_language: source.translation_language
    )
    store_pending(EVALUATION_SIGNUP_COOKIE, evaluation_signup.token, 1.day)

    redirect_to params[:authentication] == "login" ? new_user_session_path : new_user_registration_path
  rescue VideoSource::UnavailableVideo
    redirect_to root_path, alert: I18n.t("imports.errors.unavailable")
  rescue Imports::VideoPreflight::TooLong => error
    redirect_to root_path, alert: I18n.t("imports.errors.too_long", count: error.maximum_minutes)
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
