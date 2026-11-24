module Courses
  class ResolveUntitledName
    PLACEHOLDER = "Untitled Course".freeze

    def self.call(course, lesson: nil)
      return unless course.name == PLACEHOLDER

      title = (lesson || course.lessons.first)&.name.to_s.strip
      return if title.blank? || title == PLACEHOLDER

      course.with_lock do
        next unless course.name == PLACEHOLDER

        course.update!(name: title)
        course.course_translations.where(name: PLACEHOLDER).update_all(name: title, updated_at: Time.zone.now)
        title
      end
    end
  end
end
