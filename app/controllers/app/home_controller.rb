module App
  # Screen 01. Only ever this user's content — courses they imported, or added
  # from the Library. Both are Enrollments.
  class HomeController < BaseController
    # Within this window a finished import still counts as "just imported" and
    # gets the hero card. Also how the push deep link lands: it routes to
    # /app?just_imported=<slug>.
    JUST_IMPORTED_WINDOW = 48.hours

    def index
      @greeting_name = greeting_name
      @hero_course = hero_course

      candidates = candidate_enrollments
      @lesson_counts = lesson_counts_for(candidates.map(&:course) + [ @hero_course ].compact)
      @completed_counts = completed_counts_for(candidates.map(&:course_id))

      @enrollments = candidates.reject { |enrollment| finished?(enrollment) }
    end

    private

    # There's no name on User, so the email's local part stands in — "Ready to
    # practice, Ynon?". Skipped rather than guessed badly when it doesn't look
    # like a name.
    def greeting_name
      local = current_user.email.to_s.split("@").first.to_s
      return nil if local.blank?

      first = local.split(/[._+-]/).first.to_s
      return nil unless first.match?(/\A[[:alpha:]]{2,20}\z/)

      first.capitalize
    end

    # Either the course the push notification pointed at, or the most recent
    # import that finished in the last couple of days.
    def hero_course
      if params[:just_imported].present?
        course = current_user.enrolled_courses.published.find_by(slug: params[:just_imported])
        return course if course
      end

      recent = current_user.import_requests
                           .ready
                           .where(updated_at: JUST_IMPORTED_WINDOW.ago..)
                           .order(updated_at: :desc)
                           .first
      recent&.course&.then { |c| c.published? ? c : nil }
    end

    # Everything on their Home except whatever's already in the hero.
    def candidate_enrollments
      scope = current_user.enrollments
                          .includes(course: [ :language, :translation_language ])
                          .joins(:course)
                          .merge(Course.published)
                          .recently_practiced
      scope = scope.where.not(course_id: @hero_course.id) if @hero_course
      scope.limit(20).to_a
    end

    # "Keep it going" means in progress. A finished course showing "Lesson 16 of
    # 16" under that heading reads as broken — and the web's own continue-learning
    # list drops completed courses the same way.
    def finished?(enrollment)
      total = @lesson_counts[enrollment.course_id].to_i
      return false unless total.positive?

      @completed_counts[enrollment.course_id].to_i >= total
    end

    def lesson_counts_for(courses)
      ids = courses.compact.map(&:id)
      return {} if ids.empty?

      Lesson.where(course_id: ids).group(:course_id).count
    end

    def completed_counts_for(course_ids)
      return {} if course_ids.empty?

      Lesson.joins(:lesson_users)
            .where(course_id: course_ids, lesson_users: { user_id: current_user.id })
            .group(:course_id)
            .count
    end
  end
end
