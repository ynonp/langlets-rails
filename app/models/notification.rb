# One thing the app has to tell one user.
#
# The row is the record, not a side effect of delivery: it is created first and
# always, then email and push are attempted against it according to the user's
# preference (see DeliverNotificationJob). A user who receives neither still has
# a complete list on /notifications, which is what makes the preference safe to
# offer at all.
#
# The row stores what the notification is *about* — its kind, where it points,
# and the values its sentence is built from (Notifications::Content) — and not
# the sentence. `title` and `body` are rendered from `notifications.kinds.*` on
# demand. Two things follow, both of them the point:
#
#   * a copy edit applies to notifications that have already been sent, because
#     nothing was frozen at creation time; and
#   * the list renders in the reader's language.
#
# What is *not* rendered on demand is the values: "Despacito" and "2 lessons"
# are copied onto the row, so a notification still reads correctly after the
# course it is about has been deleted.
class Notification < ApplicationRecord
  belongs_to :user

  # Persisted as an integer; keep the values stable, and treat them as
  # append-only. Renaming or repurposing one silently rewords every historical
  # row that carries it. Each needs a `notifications.kinds.<name>` entry and a
  # branch in Notifications::Content.
  enum :kind, { course_ready: 0, course_failed: 1, pro_activated: 2 }, prefix: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # The copy, in the reader's language. `locale:` is explicit so the caller
  # decides: the notifications page passes the request's locale implicitly,
  # while the mailer and the push payload render in a job with no request and
  # so get I18n.default_locale. Giving those two the recipient's own language
  # needs a persisted per-user locale, which does not exist yet — when it does,
  # this is the seam it plugs into and nothing else has to move.
  def title(locale: I18n.locale) = render(:title, locale)
  def body(locale: I18n.locale) = render(:body, locale)

  def read? = read_at.present?

  # Idempotent: re-reading must not move the timestamp, so a "mark all read" on
  # every app launch cannot rewrite history.
  def mark_read!
    return if read?

    update!(read_at: Time.zone.now)
  end

  # The "entering the app means you read everything" event, and the web page's
  # "Mark all as read". One UPDATE rather than a load-and-save loop: this runs on
  # app launch and the count is unbounded.
  def self.mark_all_read!(user)
    user.notifications.unread.update_all(read_at: Time.zone.now, updated_at: Time.zone.now)
  end

  private

  # A template that cannot be rendered must not take down the notifications
  # page, which shows a hundred rows at a time and would lose all of them to one
  # bad one. The two ways it can happen are a kind whose entry was renamed away
  # and a template that grew an interpolation older rows have no value for —
  # both of them our mistake and neither of them the reader's problem, so this
  # degrades to a plain line and leaves a loud log entry.
  def render(part, locale)
    I18n.t("notifications.kinds.#{kind}.#{part}", locale: locale, raise: true, **interpolations(locale))
  rescue I18n::ArgumentError => e
    Rails.logger.error "Notification #{id} (#{kind}) could not render #{part} in #{locale}: #{e.class}: #{e.message}"
    I18n.t("notifications.unavailable", locale: locale)
  end

  # The stored values, plus the one piece of copy that stands in for a value
  # that was never captured — a failed import that never got far enough to have
  # a title. Values the template does not mention are ignored by i18n, which is
  # what lets `course_slug` ride along in the same column for Push::Notifier.
  def interpolations(locale)
    { video_title: I18n.t("notifications.kinds.default_video_title", locale: locale) }
      .merge((data || {}).symbolize_keys)
  end
end
