# Helpers for the langlets. mobile app screens (app/views/app/**).
module AppHelper
  # The mockup draws every icon as inline SVG — no icon font, no emoji. Each one
  # is a partial under app/views/app/shared/icons/, kept greppable rather than
  # compiled into a sprite (there are only ~20).
  #
  #   <%= app_icon("home", class: "w-6 h-6") %>
  def app_icon(name, **options)
    render("app/shared/icons/#{name}", **options)
  end

  # "Spanish → English · 11 lessons"
  def app_course_meta(course, lessons_count: nil)
    count = lessons_count || course.lessons.size
    pair = [ course.language, course.translation_language ].compact.map { |language| localized_language_name(language) }

    parts = []
    parts << pair.join(" → ") if pair.any?
    parts << t("courses.lesson_count", count: count)
    parts.join(" · ")
  end

  # Percentage of a course's lessons the user has finished.
  def app_progress_percent(completed, total)
    return 0 if total.to_i.zero?

    ((completed.to_f / total) * 100).round
  end

  def app_credits_label(balance)
    t("app.common.credits_left", count: balance)
  end

  # What the Approve button says. Three prices, and the button must never name
  # one the user isn't about to pay: Pro covers it, somebody else's in-flight
  # import covers it, or it costs credits. Shared by the native and web previews
  # so the two surfaces cannot describe the same charge differently.
  # Pro is the only thing that makes Approve free now — a course already in the
  # user's channel never reaches this button, because the sheet offers Open
  # instead. So there is no "free" label left to draw.
  def app_approve_label(preview:, pro:)
    return t("app.import_requests.new.approve_pro") if pro

    t("app.import_requests.new.approve", cost: t("app.common.credit_count", count: preview.cost))
  end
end
