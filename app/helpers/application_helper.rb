module ApplicationHelper
  def youtube_thumbnail_url(video_id, quality = 'hqdefault')
    Medium.youtube_thumbnail_url(video_id, quality)
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

  # Helper method to get emoji flag for language ISO code
  def language_flag(iso_code)
    flags = {
      'en' => '🇬🇧',
      'es' => '🇪🇸',
      'fr' => '🇫🇷',
      'de' => '🇩🇪',
      'he' => '🇮🇱',
      'ar' => '🇯🇴',
      'ar-JO' => '🇯🇴'
    }
    flags[iso_code] || '🌐'
  end
end
