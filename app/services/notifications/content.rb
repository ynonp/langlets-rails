module Notifications
  # Every word the app says in a notification, in one place.
  #
  # This exists because the same sentence used to be written three times — once
  # in a mailer view, once in an APNs payload builder, and nowhere at all for
  # anything that wanted to show a list. A kind is added here and it is worded
  # once for all three surfaces.
  #
  # `build` returns the copy only. Persisting it and delivering it are
  # Notifications::Deliver's job.
  class Content
    Built = Data.define(:title, :body, :url, :data)

    # APNs rejects payloads over 4KB, and a provider-supplied video title is the
    # only unbounded thing that reaches one.
    MAX_TITLE_LENGTH = 120

    class UnknownKind < StandardError; end

    def self.build(kind, context = {}) = new(kind, context).build

    def initialize(kind, context)
      @kind = kind.to_sym
      @context = context
    end

    def build
      case @kind
      when :course_ready then course_ready
      when :course_failed then course_failed
      when :pro_activated then pro_activated
      else raise UnknownKind, "no content for notification kind #{@kind.inspect}"
      end
    end

    private

    attr_reader :context

    # "Your course is ready!" — the wording the mockup's screen 07 uses,
    # including the curly quotes around the title.
    def course_ready
      course = context[:course]
      lessons = course&.lessons&.size.to_i

      Built.new(
        title: "Your course is ready!",
        body: "“#{video_title(course)}” is now #{lessons} #{'lesson'.pluralize(lessons)}. Tap to start practicing.",
        # The course itself, which works on both clients. Deliberately not
        # `/app?just_imported=…`: that screen is native-only and bounces a web
        # reader to the home page. The native deep link is unaffected — the app
        # routes on `course_slug` below and still lands on Home with the new
        # course as its hero.
        url: course&.slug.present? ? "/courses/#{course.slug}" : "/",
        data: { "course_slug" => course&.slug }.compact
      )
    end

    def course_failed
      course = context[:course]
      reason = context[:reason].to_s

      Built.new(
        title: "Course creation failed",
        body: "We couldn't build a course from “#{video_title(course)}”. No credit was charged — try importing it again.",
        url: "/app/import_requests",
        # Kept off the body and out of the push on purpose: it is a pipeline
        # message ("Word translation count mismatch"), useful in the email's
        # details block and to support, not in a lock-screen banner.
        data: { "reason" => reason.truncate(500) }.compact_blank
      )
    end

    def pro_activated
      Built.new(
        title: "You're a Pro subscriber now",
        body: "Great — Langlets Pro is active. Import as much as you like; every course you add is included.",
        url: "/app/pro/success",
        data: {}
      )
    end

    # A failed import may never have got as far as a course row, and the
    # ImportRequest carries the provider title in that case.
    def video_title(course)
      title = course&.name.presence || context[:title].presence || "Your video"
      title.truncate(MAX_TITLE_LENGTH)
    end
  end
end
