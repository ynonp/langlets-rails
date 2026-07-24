module Tiktok
  # Parsing TikTok URLs. Mirrors Youtube::Url so VideoSource can treat the two
  # interchangeably, with one important asymmetry:
  #
  # A YouTube id is always present in the URL. A TikTok *short* link
  # (vt.tiktok.com/ZSXvNVQwY) carries a redirect token instead of the numeric
  # post id, and there is no offline way to trade one for the other — only
  # Tiktok::Oembed can, because TikTok resolves the redirect server-side. So
  # video_id returns nil for short links while match?/valid? still return true:
  # we know it's a TikTok URL, we just don't know which post yet.
  #
  # That's fine for the flows that matter. Imports::Create and Imports::Preview
  # both call oEmbed before doing anything with the id, and oEmbed returns both
  # the numeric id and a fully canonical @user/video/id URL.
  module Url
    module_function

    # www.tiktok.com/@user/video/123, /photo/123, /embed/v2/123, /player/v1/123,
    # m.tiktok.com/v/123.html — anything carrying the numeric post id.
    # The lookbehind is load-bearing: without it "nottiktok.com/@a/video/123"
    # matches, and an attacker-chosen host would be treated as a TikTok post.
    # `tiktok.com` must start a hostname — preceded by "//" or by a subdomain dot.
    HOST = /(?<=[\/.])tiktok\.com/i

    ID_PATTERN = %r{
      #{HOST}/
      (?:
        @[\w.\-]+/(?:video|photo)/
        | (?:embed(?:/v2)?|player/v1|v)/
      )
      (\d{6,25})
    }xi

    # vt.tiktok.com/ZSXvNVQwY, vm.tiktok.com/ZMxxxx, www.tiktok.com/t/ZTxxxx —
    # the share-sheet forms. Resolvable only through oEmbed.
    SHORT_PATTERN = %r{
      (?:
        (?<=[\/.])(?:vt|vm)\.tiktok\.com/
        | #{HOST}/t/
      )
      ([\w\-]{5,})
    }xi

    def match?(url)
      return false if url.blank?

      url.to_s.match?(ID_PATTERN) || url.to_s.match?(SHORT_PATTERN)
    end

    # The numeric post id, or nil for a short link (see the note above).
    def video_id(url)
      return nil if url.blank?

      match = url.to_s.match(ID_PATTERN)
      match && match[1]
    end

    def short_code(url)
      return nil if url.blank? || url.to_s.match?(ID_PATTERN)

      match = url.to_s.match(SHORT_PATTERN)
      match && match[1]
    end

    # One spelling per video. When the author handle is in the URL we keep it,
    # because @user/video/id is the form TikTok itself serves and the form
    # ElevenLabs accepts as a sourceUrl. A bare id (from an /embed/ or /player/
    # link) uses @i, TikTok's placeholder handle, which redirects to the real
    # one. A short link can't be canonicalized offline, so it is normalized —
    # scheme, host and path, no tracking query — and left for oEmbed to resolve.
    def canonical(url)
      return nil unless match?(url)

      if (id = video_id(url))
        handle = author_handle(url)
        return "https://www.tiktok.com/@#{handle || 'i'}/video/#{id}"
      end

      normalized_short(url)
    end

    def canonical_for(video_id, author_handle = nil)
      return nil if video_id.blank?

      "https://www.tiktok.com/@#{author_handle.presence || 'i'}/video/#{video_id}"
    end

    def author_handle(url)
      match = url.to_s.match(%r{tiktok\.com/@([\w.\-]+)/(?:video|photo)/}i)
      handle = match && match[1]
      handle unless handle == "i"
    end

    # TikTok has no bare-id form worth guessing at: an id is a long run of
    # digits, and treating any such string as a video would turn Library
    # searches into id lookups. So loose_* is just the strict parse.
    def loose_video_id(input) = video_id(input)
    def loose_canonical(input) = canonical(input)

    def valid?(url) = match?(url)

    def normalized_short(url)
      uri = URI.parse(url.to_s.strip)
      return nil if uri.host.blank?

      "#{uri.scheme || 'https'}://#{uri.host}#{uri.path.to_s.chomp('/')}"
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :normalized_short
  end
end
