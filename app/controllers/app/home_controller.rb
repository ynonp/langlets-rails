module App
  # Screen 01. The user's unfinished courses (Enrollments — imported or added
  # from the Library), followed by a four-item preview of the visible Library.
  class HomeController < BaseController
    before_action :set_daily_vocab_reviews

    # Within this window a finished import still counts as "just imported" and
    # gets the hero card. Also how the push deep link lands: it routes to
    # /app?just_imported=<slug>.
    JUST_IMPORTED_WINDOW = 24.hours

    def index
      @hero_course = hero_course
      @playlists = current_user.playlists
                               .includes(courses: [ :language, { course_translations: :language } ])
                               .order(updated_at: :desc)
                               .to_a

      @latest_import_items = ChannelContentQuery
        .new(user: current_user, include_untranslated: true)
        .items
        .reorder("courses.created_at DESC", "channel_items.id DESC")
        .limit(4)
        .to_a
      latest_import_courses = @latest_import_items.map(&:course)
      @latest_import_enrolled_course_ids = current_user.enrollments
                                                       .where(course_id: latest_import_courses.map(&:id))
                                                       .pluck(:course_id)
                                                       .to_set

      candidates = candidate_enrollments
      @lesson_counts = lesson_counts_for(candidates.map(&:course) + latest_import_courses + [ @hero_course ].compact)
      @completed_counts = completed_counts_for(candidates.map(&:course_id))

      unfinished = candidates.reject { |enrollment| finished?(enrollment) }

      # "Continue" remains for started work. The separate Latest imports shelf
      # comes from Library, so it does not depend on Enrollment state.
      @enrollments = unfinished.select(&:last_practiced_at?).first(2)
      @has_unfinished_courses = @hero_course.present? || unfinished.any?
    end

    private

    # Either the course the push notification pointed at, or the most recent
    # import that finished in the last day — but only if the user hasn't started
    # it yet.
    def hero_course
      if params[:just_imported].present?
        course = current_user.enrolled_courses.published.find_by(slug: params[:just_imported])
        return course if course && course.readable_by?(current_user) && !started?(course)
      end

      recent = current_user.import_requests
                           .ready
                           .where(updated_at: JUST_IMPORTED_WINDOW.ago..)
                           .order(updated_at: :desc)
                           .first
      course = recent&.course
      return nil unless course&.published?
      return nil unless course.readable_by?(current_user)
      return nil if started?(course)

      course
    end

    def started?(course)
      LessonUser.joins(:lesson).where(
        user_id: current_user.id,
        lesson: { course_id: course.id }
      ).exists?
    end

    # Every account course except whatever is already in the hero. Started and
    # not-started enrollments both belong here; completion is filtered after the
    # grouped lesson counts are loaded. An Enrollment survives its Channel going
    # private, so readability is re-checked here rather than trusted from when it
    # was created.
    def candidate_enrollments
      scope = current_user.enrollments
                          .includes(course: [ :language, { course_translations: :language } ])
                          .joins(:course)
                          .merge(Course.published)
                          .merge(ChannelContentQuery.courses_visible_to(current_user))
                          .recently_practiced
      scope = scope.where.not(course_id: @hero_course.id) if @hero_course
      scope.to_a
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
