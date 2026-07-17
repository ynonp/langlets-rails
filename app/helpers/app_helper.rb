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
    pair = [ course.language&.english_name, course.translation_language&.english_name ].compact

    parts = []
    parts << pair.join(" → ") if pair.any?
    parts << pluralize(count, "lesson")
    parts.join(" · ")
  end

  # Percentage of a course's lessons the user has finished.
  def app_progress_percent(completed, total)
    return 0 if total.to_i.zero?

    ((completed.to_f / total) * 100).round
  end

  def app_credits_label(balance)
    "#{balance} #{'credit'.pluralize(balance)} left"
  end
end
