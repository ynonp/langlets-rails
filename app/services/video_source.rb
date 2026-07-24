# The one place that knows which video providers exist.
#
# Everything that used to call Youtube::Url / Youtube::Oembed directly now goes
# through here, so adding a provider is a new pair of modules plus one line in
# PROVIDERS rather than a grep across the app. The two provider modules answer
# the same questions:
#
#   <Provider>::Url    — video_id / canonical / valid? (pure string work, no network)
#   <Provider>::Oembed — fetch(url) -> VideoSource::Video (one HTTP call)
#
# Naming note: the columns are still called youtube_video_id / youtube_url
# (courses, import_requests). They hold whatever provider's id, and they back
# idx_courses_published_video_language — the partial unique index that makes a
# double import a database impossibility. Renaming them is a dedupe migration,
# not a rename, so the names stayed and the meaning widened.
module VideoSource
  # Raised for anything we can't turn into a course: malformed URL, unsupported
  # host, private or deleted video. Youtube::Oembed::UnavailableVideo is an alias
  # of this, so the rescues written before TikTok existed still catch TikTok.
  class UnavailableVideo < StandardError; end

  # provider defaults to :youtube so pre-existing callers (and their tests) that
  # build a Video without one keep working.
  Video = Data.define(:provider, :video_id, :title, :author_name, :thumbnail_url, :canonical_url) do
    def initialize(provider: :youtube, **rest) = super

    def youtube? = provider == :youtube
    def tiktok? = provider == :tiktok
  end

  PROVIDERS = %i[youtube tiktok].freeze
  DEFAULT_PROVIDER = :youtube

  module_function

  # :youtube, :tiktok, or nil when no provider claims the URL.
  def provider(url)
    return nil if url.blank?

    PROVIDERS.find { |name| url_module(name).match?(url) }
  end

  def url_module(name)
    case name&.to_sym
    when :youtube then Youtube::Url
    when :tiktok  then Tiktok::Url
    end
  end

  def oembed_module(name)
    case name&.to_sym
    when :youtube then Youtube::Oembed
    when :tiktok  then Tiktok::Oembed
    end
  end

  # The provider's id for this video. nil when the URL belongs to no provider,
  # and also nil for a TikTok short link (vt.tiktok.com/ZSXvNVQwY) — those carry
  # a redirect token rather than the numeric post id, and only oEmbed can trade
  # one for the other. Callers that need an id from arbitrary input should use
  # fetch, which resolves it.
  def video_id(url)
    dispatch(url) { |mod| mod.video_id(url) }
  end

  # One spelling per video, so courses.main_media_url, media.url and
  # create_song_progresses.youtubeurl line up for dedupe.
  def canonical(url)
    dispatch(url) { |mod| mod.canonical(url) }
  end

  def valid?(url)
    provider(url).present?
  end

  # video_id/canonical, but also accepting a bare YouTube id typed on its own.
  # Only the Add Video sheet uses these: it has to tell "this is a video" from
  # "this is a search term".
  def loose_video_id(input)
    dispatch(input) { |mod| mod.loose_video_id(input) } || Youtube::Url.loose_video_id(input)
  end

  def loose_canonical(input)
    dispatch(input) { |mod| mod.loose_canonical(input) } || Youtube::Url.loose_canonical(input)
  end

  # "Is this pasteable as a video?" — the question the Add Video sheet actually
  # needs answered, and deliberately not `loose_video_id(input).present?`.
  # A TikTok share link has no id in it until oEmbed resolves one, so asking for
  # an id would reject the single most common thing a user pastes.
  def importable?(input)
    loose_canonical(input).present?
  end

  # A cover image derivable from the URL alone, with no network call — which is
  # the whole reason course cards can render a grid without N requests.
  # YouTube has a public static pattern; TikTok's covers are signed CDN URLs, so
  # this returns nil there and the caller falls back to courses.thumbnail_url,
  # captured from oEmbed at import time.
  def derived_thumbnail_url(url, quality = "hqdefault")
    name = provider(url)
    return nil unless name == :youtube

    id = Youtube::Url.video_id(url)
    id && Youtube::Url.thumbnail_url(id, quality)
  end

  # The single availability check. Raises UnavailableVideo for anything that
  # can't become a course — which is what lets Imports::Create verify a video
  # before it moves a credit.
  def fetch(url)
    name = provider(url)
    raise UnavailableVideo, "unsupported video URL: #{url.inspect}" if name.nil?

    oembed_module(name).fetch(url)
  end

  # Best-effort title for background paths that would rather use a weak title
  # than fail an import someone has already paid for.
  def fetch_title(url, fallback: nil)
    fetch(url).title
  rescue UnavailableVideo, StandardError => e
    Rails.logger.warn "oEmbed title lookup failed for #{url.inspect}: #{e.message}"
    fallback || video_id(url) || "Untitled Course"
  end

  def dispatch(url)
    name = provider(url)
    name && yield(url_module(name))
  end
  private_class_method :dispatch
end
