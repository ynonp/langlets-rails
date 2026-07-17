module ApplicationHelper
  def youtube_thumbnail_url(video_id, quality = 'hqdefault')
    Medium.youtube_thumbnail_url(video_id, quality)
  end

  def course_youtube_video_id(course)
    course.youtube_video_id.presence || Youtube::Url.video_id(course.main_media_url)
  end

  def link_to_next_activity(text, path, opts)
    route = Rails.application.routes.recognize_path(path)
    if route[:action] == "finish"
      link_to text, path, {**opts, data: {:"turbo-frame" => "_top", :"turbo-action" => "replace"}}
    else
      link_to text, path, opts
    end
  end

  # Maps a language ISO/short code to an OKLCH hue used by the Sprout design system.
  # Used to tint language badges, thumbnails, and accents per-language.
  LANG_HUES = {
    "es" => 145, "es-ES" => 145, "es-MX" => 145,
    "ar" => 25, "ar-JO" => 25, "ar-EG" => 25,
    "fr" => 268, "fr-FR" => 268,
    "he" => 220, "he-IL" => 220,
    "de" => 52, "de-DE" => 52,
    "en" => 150, "en-US" => 150, "en-GB" => 150
  }.freeze

  def lang_hue(code)
    return 150 if code.blank?

    key = code.to_s
    LANG_HUES[key] || LANG_HUES[key.split("-").first.downcase] || 150
  end

  # Short uppercase language code for the Sprout language badge (e.g. "ES", "AR").
  def lang_badge_code(language)
    return "" if language.nil?

    raw = language.try(:iso_name) || language.try(:short_code) || language.to_s
    raw.to_s.split("-").first.upcase
  end

  # Helper method to determine CSS background class based on streak status
  def streak_background_class(streak_status)
    case streak_status
    when :completed_today
      "bg-orange-500"      # Regular orange - today's lesson done
    when :at_risk
      "bg-orange-100 text-black"      # Lighter orange - streak at risk
    else
      "bg-orange-500"      # Regular orange - no streak
    end
  end
end
