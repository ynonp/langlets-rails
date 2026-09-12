module Imports
  # Only a published course is evidence strong enough to skip detection. Match
  # by indexed provider ID, with canonical URL as a fallback for legacy courses,
  # and decline the shortcut if the matched records disagree about the source.
  class KnownSourceLanguage
    def self.for(video:)
      published = Course.published
      language_ids = if video.video_id.present?
        published.where(youtube_video_id: video.video_id).distinct.limit(2).pluck(:language_id)
      else
        []
      end
      if language_ids.empty?
        language_ids = published.where(main_media_url: video.canonical_url)
                                .distinct.limit(2).pluck(:language_id)
      end
      return unless language_ids.one?

      Language.find_by(id: language_ids.first)
    end
  end
end
