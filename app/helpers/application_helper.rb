module ApplicationHelper
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

  def extract_youtube_id(url)
    return '' if url.blank?
    
    # Handle various YouTube URL formats
    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&\?\/]+)/,
      /youtube\.com\/embed\/([^&\?\/]+)/,
      /youtube\.com\/v\/([^&\?\/]+)/
    ]
    
    patterns.each do |pattern|
      match = url.match(pattern)
      return match[1] if match
    end
    
    ''
  end
end
