module ApplicationHelper
  def youtube_thumbnail_url(video_id, quality = 'maxresdefault')
    "https://img.youtube.com/vi/#{video_id}/#{quality}.jpg"
  end
end
