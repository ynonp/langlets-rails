module ApplicationHelper
  # Hotwire Native detection helpers
  def turbo_native_app?
    request.user_agent.to_s.match?(/Turbo Native/i)
  end

  def turbo_native_ios?
    request.user_agent.to_s.match?(/Turbo Native.*iOS/i)
  end

  def turbo_native_android?
    request.user_agent.to_s.match?(/Turbo Native.*Android/i)
  end

  def youtube_thumbnail_url(video_id, quality = 'hqdefault')
    "https://img.youtube.com/vi/#{video_id}/#{quality}.jpg"
  end

  def link_to_next_activity(text, path, opts)
    route = Rails.application.routes.recognize_path(path)
    if route[:action] == "finish"
      link_to text, path, {**opts, data: {:"turbo-frame" => "_top"}}
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
