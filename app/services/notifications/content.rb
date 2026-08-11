module Notifications
  # What each kind of notification is *about*: where it points, and the values
  # its sentence is built from. Not the sentence itself — that lives in
  # `notifications.kinds.*` in the locale files, and is rendered by
  # Notification#title/#body at the moment someone reads it.
  #
  # The split matters because the values are snapshots and the wording is not.
  # "Despacito" and "2 lessons" are facts about an import that finished, and
  # have to survive the course being deleted, so they are copied onto the row.
  # The sentence wrapped around them is a thing we can change our minds about,
  # including after it has been sent.
  #
  # The rule that keeps that true: **values, never ids.** A `course_id` here
  # would put the copy back at the mercy of the course still existing.
  class Content
    Built = Data.define(:url, :data)

    # APNs rejects payloads over 4KB, and a provider-supplied video title is the
    # only unbounded thing that reaches one. Applied here, as the value is
    # written, so the stored param is already safe for every surface.
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

    def course_ready
      course = context[:course]

      Built.new(
        # The course itself, which works on both clients. Deliberately not
        # `/app?just_imported=…`: that screen is native-only and bounces a web
        # reader to the home page. The native deep link is unaffected — the app
        # routes on `course_slug` below and still lands on Home with the new
        # course as its hero.
        url: course&.slug.present? ? "/courses/#{course.slug}" : "/",
        data: {
          "video_title" => video_title(course),
          # `count` and not `lessons`: it is the key i18n pluralizes on, so the
          # locale file decides how many forms a language needs rather than
          # `String#pluralize` deciding it can only ever be English.
          # The builder may have loaded `course.lessons` while it was still
          # empty. Query the persisted rows so that cached pipeline state cannot
          # freeze the ready notification at zero.
          "count" => course&.lessons&.count.to_i,
          # Not interpolated into anything — this is the iOS deep link, read
          # back by Push::Notifier. Extra values are ignored by the templates.
          "course_slug" => course&.slug
        }.compact
      )
    end

    def course_failed
      Built.new(
        # No destination: unlike a ready course or an activated subscription,
        # a failed import has nothing specific to open — "/app/import_requests/new"
        # would just land on the empty Add Video screen, not the failure
        # itself. Omitted rather than pointed anywhere, so the notification
        # list and the push payload don't offer an "Open" that goes nowhere
        # useful.
        url: nil,
        data: {
          "video_title" => video_title(context[:course])
        }.compact_blank
      )
    end

    def pro_activated
      Built.new(url: "/app/pro/success", data: {})
    end

    # A failed import may never have got as far as a course row, and the
    # ImportRequest carries the provider title in that case.
    #
    # Nil when there is neither, rather than a stand-in like "Your video": that
    # stand-in is copy, so it is the renderer's business and not something to
    # freeze into the row in whatever language happened to be current when an
    # import failed. Notification#interpolations supplies it.
    def video_title(course)
      title = course&.name.presence || context[:title].presence
      title&.truncate(MAX_TITLE_LENGTH)
    end
  end
end
