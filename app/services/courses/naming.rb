module Courses
  # Turns a video title into a course name and slug. Extracted from
  # ImportCourseJob (which typed it out inline) so the mobile import and the
  # admin importer can't drift apart.
  #
  # The mobile flow has no field for a human to type a slug, so this has to be
  # total: every title, in every language, must yield a valid, unique-ish slug.
  # String#slug_for_language keeps Unicode letters, so Hebrew and Arabic titles
  # slug fine ("ולנטינה והדרקון" -> "ולנטינה-והדרקון"). The cases that don't are
  # titles with no letters at all — an emoji-only title slugs to "" and a
  # punctuation-only one to "-", both of which fail `validates :slug, presence`.
  # Those fall back to the video id.
  class Naming
    # Below this, the slug carries no information (and "" / "-" are invalid).
    MIN_SLUG_LENGTH = 3

    Result = Data.define(:name, :slug)

    def self.call(title:, video_id:)
      new(title: title, video_id: video_id).call
    end

    def initialize(title:, video_id:)
      @title = title.to_s.strip
      @video_id = video_id.presence
    end

    def call
      Result.new(name: name, slug: slug)
    end

    private

    attr_reader :title, :video_id

    def name
      title.presence || video_id || "Untitled Course"
    end

    # Always suffixed with the video id, which makes collisions between different
    # videos essentially impossible and lets a slug be traced back to its source.
    def slug
      base = title.slug_for_language.to_s
      base = video_id.downcase if base.length < MIN_SLUG_LENGTH && video_id

      video_id ? "#{base}-#{video_id.downcase}" : base
    end
  end
end
