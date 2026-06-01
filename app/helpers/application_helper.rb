module ApplicationHelper
  LANGUAGE_FLAG_MAP = {
    "ar" => "JO",
    "de" => "DE",
    "en" => "US",
    "es" => "ES",
    "fr" => "FR",
    "he" => "IL"
  }.freeze

  def youtube_thumbnail_url(video_id, quality = 'hqdefault')
    Medium.youtube_thumbnail_url(video_id, quality)
  end

  def language_filter_url(lang_code = nil)
    query = request.query_parameters.except("lang")
    query["lang"] = lang_code if lang_code.present?
    query_string = query.to_query

    query_string.present? ? "#{request.path}?#{query_string}" : request.path
  end

  def language_flag_emoji(language)
    iso = language.iso_name.to_s
    language_code, region_code = iso.split("-", 2)
    country_code = (region_code || LANGUAGE_FLAG_MAP[language_code] || language_code).to_s.upcase

    return "🌐" unless country_code.match?(/\A[A-Z]{2}\z/)

    country_code.chars.map { |char| (char.ord + 127397).chr(Encoding::UTF_8) }.join
  end

  def link_to_next_activity(text, path, opts)
    route = Rails.application.routes.recognize_path(path)
    if route[:action] == "finish"
      link_to text, path, {**opts, data: {:"turbo-frame" => "_top", :"turbo-action" => "replace"}}
    else
      link_to text, path, opts
    end
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
