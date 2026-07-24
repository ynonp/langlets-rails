module ApplicationHelper
  def homepage_subhead(language_code)
    base_language_code = language_code.to_s.split("-").first.to_s.downcase
    return t("subhead.default") if base_language_code.blank?

    language_key = "subhead.#{base_language_code}"

    I18n.exists?(language_key) ? t(language_key) : t("subhead.default")
  end

  def youtube_thumbnail_url(video_id, quality = 'hqdefault')
    Medium.youtube_thumbnail_url(video_id, quality)
  end

  # The cover to render for a course card, whatever provider it came from.
  # Course#thumbnail_url reads the stored column then derives, so YouTube rows
  # cost nothing and TikTok rows use the URL captured at import.
  def course_thumbnail_url(course, quality = 'hqdefault')
    course&.thumbnail_url(quality)
  end

  def course_youtube_video_id(course)
    course&.video_id
  end
  alias_method :course_video_id, :course_youtube_video_id

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

  # Language name in the visitor's UI locale, falling back to the DB English name.
  def localized_language_name(language)
    return "" if language.nil?

    key = language.iso_name.to_s.split("-").first.downcase
    I18n.exists?("languages.#{key}") ? t("languages.#{key}") : language.english_name
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
