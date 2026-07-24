module SeoHelper
  DEFAULT_DESCRIPTION = "Learn languages through interactive video clips. " \
    "Practice listening, speaking, and comprehension with songs, TV shows, " \
    "and real-world content powered by AI."

  def render_meta_tags(title:, description:, url:, image_url: nil, type: "website",
                       image_width: 1280, image_height: 720)
    tags = []
    tags << tag.meta(name: "description", content: description)
    tags << tag.link(rel: "canonical", href: url)

    tags << tag.meta(property: "og:type", content: type)
    tags << tag.meta(property: "og:url", content: url)
    tags << tag.meta(property: "og:title", content: title)
    tags << tag.meta(property: "og:description", content: description)
    tags << tag.meta(property: "og:site_name", content: "Langlets")
    tags << tag.meta(property: "og:locale", content: "en_US")

    if image_url.present?
      tags << tag.meta(property: "og:image", content: image_url)
      tags << tag.meta(property: "og:image:width", content: image_width)
      tags << tag.meta(property: "og:image:height", content: image_height)
    end

    card_type = image_url.present? ? "summary_large_image" : "summary"
    tags << tag.meta(name: "twitter:card", content: card_type)
    tags << tag.meta(name: "twitter:url", content: url)
    tags << tag.meta(name: "twitter:title", content: title)
    tags << tag.meta(name: "twitter:description", content: description)
    tags << tag.meta(name: "twitter:image", content: image_url) if image_url.present?

    safe_join(tags, "\n    ")
  end

  def course_description(course)
    if course.respond_to?(:description) && course.description.present?
      return course.description
    end

    lang = course.language
    language_name = lang&.english_name || "a new language"
    lesson_count = course.lessons.size

    "Learn #{language_name} through \"#{course.name}\" — an interactive video course " \
    "with #{ActionController::Base.helpers.pluralize(lesson_count, 'lesson')}. " \
    "Practice listening, speaking, and comprehension with AI-powered activities on Langlets."
  end

  def playlist_description(playlist)
    return playlist.description if playlist.description.present?

    course_count = playlist.courses.published.count
    "A curated playlist with #{ActionController::Base.helpers.pluralize(course_count, 'interactive video course')}. " \
    "Master \"#{playlist.name}\" step by step on Langlets."
  end

  # Name predates TikTok. Returns whichever provider's id the URL carries, and —
  # unlike the version it replaces — returns nil rather than `url.split("v=").last`
  # for something unparseable, so a junk id can't end up inside a meta tag or a
  # structured-data embedUrl.
  def extract_video_id(url)
    VideoSource.video_id(url)
  end
  alias_method :extract_youtube_id, :extract_video_id

  # Where the provider's embeddable player lives. Used by the course preview
  # iframe and by VideoObject structured data.
  def video_embed_url(url_or_course)
    url = url_or_course.respond_to?(:main_media_url) ? url_or_course.main_media_url : url_or_course
    id = VideoSource.video_id(url)
    return nil if id.blank?

    case VideoSource.provider(url)
    when :tiktok  then "https://www.tiktok.com/player/v1/#{id}"
    when :youtube then "https://www.youtube.com/embed/#{id}"
    end
  end

  # TikTok is shot vertically; forcing its player into a 16:9 box letterboxes it
  # into a stripe with black bars either side.
  def video_aspect_ratio(url_or_course)
    url = url_or_course.respond_to?(:main_media_url) ? url_or_course.main_media_url : url_or_course
    VideoSource.provider(url) == :tiktok ? "9/16" : "16/9"
  end

  def canonical_url(path)
    "https://langlets.app#{path}"
  end
end
