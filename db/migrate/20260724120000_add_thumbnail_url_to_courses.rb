class AddThumbnailUrlToCourses < ActiveRecord::Migration[8.0]
  # Nullable and deliberately not backfilled. YouTube covers stay derivable from
  # main_media_url (img.youtube.com/vi/ID/hqdefault.jpg), so every existing row
  # keeps rendering exactly as it does today. TikTok covers are signed CDN URLs
  # that only come back from oEmbed, so those are captured at import time and
  # stored here. Course#thumbnail_url reads the column, then falls back to
  # derivation.
  def change
    add_column :courses, :thumbnail_url, :string
  end
end
