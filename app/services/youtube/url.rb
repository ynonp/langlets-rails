module Youtube
  # Parsing YouTube URLs. Extracted from ImportCourseJob so the import pipeline,
  # the mobile Add screen and the share extension all agree on what a video id is
  # and what the canonical form of a URL looks like.
  module Url
    module_function

    # Covers watch?v=, youtu.be/, /shorts/, /embed/, /v/ and any of them carrying
    # extra query params before v=.
    PATTERN = %r{
      (?:
        youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|shorts/|.*[?&]v=)
        |
        youtu\.be/
      )
      ([^"&?/\s]{11})
    }x

    def video_id(url)
      return nil if url.blank?

      match = url.to_s.match(PATTERN)
      match && match[1]
    end

    # One spelling per video. youtu.be/X and youtube.com/watch?v=X&t=9 are the
    # same video, but they're different strings — and courses.main_media_url,
    # media.url and create_song_progresses.youtubeurl all have to line up for
    # dedupe to work.
    def canonical(url)
      id = video_id(url)
      id && "https://www.youtube.com/watch?v=#{id}"
    end

    def valid?(url)
      video_id(url).present?
    end
  end
end
