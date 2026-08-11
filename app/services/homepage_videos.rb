class HomepageVideos
  PAGE_LIMIT = 8

  Video = Data.define(:title, :url, :clip_language, :thumbnail_url)

  def self.all
    # Keep this file live rather than memoizing it. The list is intentionally
    # operator-editable, and Rails does not reload application classes when
    # only a YAML file changes, which otherwise leaves a development server
    # showing stale examples until it is restarted.
    YAML.safe_load_file(Rails.root.join("config/homepage_videos.yml"), symbolize_names: true).map do |entry|
      Video.new(
        title: entry.fetch(:title),
        url: entry.fetch(:url),
        clip_language: entry.fetch(:clip_language),
        thumbnail_url: VideoSource.derived_thumbnail_url(entry.fetch(:url))
      )
    end.freeze
  end

  def self.find_by_url(url)
    canonical_url = VideoSource.loose_canonical(url)
    return if canonical_url.blank?

    all.find { |video| VideoSource.loose_canonical(video.url) == canonical_url }
  end

  def self.for_page(random: Random)
    all.sample(PAGE_LIMIT, random: random)
  end
end
