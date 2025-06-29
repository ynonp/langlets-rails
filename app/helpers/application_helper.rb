module ApplicationHelper
  def youtube_thumbnail_url(video_id, quality = 'hqdefault')
    "https://img.youtube.com/vi/#{video_id}/#{quality}.jpg"
  end
end
