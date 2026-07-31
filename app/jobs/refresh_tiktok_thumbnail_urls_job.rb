# TikTok oEmbed returns signed CDN thumbnail URLs that expire after roughly two
# days. Refresh them daily so course cards never reach the expiry embedded in a
# stored URL. The lookup stays out of Course#thumbnail_url: rendering a gallery
# must not make synchronous network requests or mutate records.
class RefreshTiktokThumbnailUrlsJob < ApplicationJob
  queue_as :default

  def perform
    refreshed = 0
    failed = 0

    tiktok_courses.find_each do |course|
      next unless course.tiktok?

      video = VideoSource.fetch(course.main_media_url)
      next if video.thumbnail_url.blank?

      unless video.tiktok? && video.video_id.to_s == course.video_id.to_s
        raise VideoSource::UnavailableVideo, "TikTok oEmbed returned a different video"
      end

      course.update_column(:thumbnail_url, video.thumbnail_url)
      refreshed += 1
    rescue StandardError => e
      failed += 1
      Rails.logger.warn(
        "RefreshTiktokThumbnailUrlsJob could not refresh course #{course.id}: #{e.message}"
      )
    end

    Rails.logger.info(
      "RefreshTiktokThumbnailUrlsJob refreshed #{refreshed} TikTok thumbnails; #{failed} failed"
    )
  end

  private

  # Imports persist canonical URLs on www.tiktok.com. Keep the provider check as
  # a second boundary so a malformed or legacy value containing that text never
  # reaches TikTok oEmbed.
  def tiktok_courses
    Course.where("main_media_url ILIKE ?", "%://www.tiktok.com/%")
  end
end
