module Push
  # "Your course is ready!" — the payload, exactly as the mockup's screen 07
  # words it, including the curly quotes around the title.
  class CourseReadyNotification
    TITLE = "Your course is ready!".freeze

    # APNs rejects payloads over 4KB. A YouTube title can be long, and the title
    # is the only unbounded part.
    MAX_TITLE_LENGTH = 120

    def self.payload_for(import_request, badge: nil)
      new(import_request, badge: badge).payload
    end

    def initialize(import_request, badge: nil)
      @import_request = import_request
      @badge = badge
    end

    def payload
      {
        alert: { title: TITLE, body: body },
        sound: "default",
        badge: @badge,
        custom_payload: {
          # What the app reads to deep-link into the new course.
          course_slug: @import_request.course&.slug,
          import_request_id: @import_request.id
        }.compact
      }.compact
    end

    private

    def body
      title = @import_request.title.presence || "Your video"
      lessons = @import_request.course&.lessons&.size.to_i

      "“#{title.truncate(MAX_TITLE_LENGTH)}” is now #{lessons} #{'lesson'.pluralize(lessons)}. Tap to start practicing."
    end
  end
end
