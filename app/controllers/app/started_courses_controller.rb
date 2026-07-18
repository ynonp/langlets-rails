module App
  # Every published course the user has actually opened, including completed
  # courses. Enrollment#last_practiced_at is the app's canonical "started"
  # signal and keeps this distinct from courses merely added from the Library.
  class StartedCoursesController < BaseController
    def index
      @enrollments = current_user.enrollments
                                 .in_progress
                                 .includes(course: [ :language, { course_translations: :language } ])
                                 .joins(:course)
                                 .merge(Course.published)
                                 .recently_practiced
                                 .to_a

      course_ids = @enrollments.map(&:course_id)
      @lesson_counts = Lesson.where(course_id: course_ids).group(:course_id).count
      @completed_counts = Lesson.joins(:lesson_users)
                                .where(course_id: course_ids, lesson_users: { user_id: current_user.id })
                                .group(:course_id)
                                .count
    end
  end
end
