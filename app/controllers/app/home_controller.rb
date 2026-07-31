module App
  # Screen 01. The user's own courses (Enrollments — imported or added from the
  # Library), plus a compact horizontal shelf of Library suggestions.
  class HomeController < BaseController
    # Within this window a finished import still counts as "just imported" and
    # gets the hero card. Also how the push deep link lands: it routes to
    # /app?just_imported=<slug>.
    JUST_IMPORTED_WINDOW = 24.hours

    def index
      @hero_course = hero_course
      @learning_language = Language.find_by(iso_name: current_language_code) if current_language_code.present?
      @daily_vocab_language = current_language_code if
        current_user.daily_vocab_review_available?(current_language_code)
      @playlists = current_user.playlists
                               .includes(courses: [ :language, { course_translations: :language } ])
                               .order(updated_at: :desc)
                               .to_a

      candidates = candidate_enrollments
      @lesson_counts = lesson_counts_for(candidates.map(&:course) + [ @hero_course ].compact)
      @completed_counts = completed_counts_for(candidates.map(&:course_id))

      # "Continue" is in-progress work only; finished courses
      # drop out (they'd read as broken under that heading).
      @enrollments = candidates.reject { |enrollment| finished?(enrollment) }.first(2)

      # The paste CTA is now the primary way in, so there's no separate first-run
      # picker — the library grid carries the empty account too, hence four picks.
      @library_items = library_picks(count: 4)
      @library_picks = @library_items.map(&:course)
      @lesson_counts.merge!(lesson_counts_for(@library_picks))
    end

    private

    # Either the course the push notification pointed at, or the most recent
    # import that finished in the last day — but only if the user hasn't started
    # it yet.
    def hero_course
      if params[:just_imported].present?
        course = current_user.enrolled_courses.published.find_by(slug: params[:just_imported])
        return course if course && !started?(course)
      end

      recent = current_user.import_requests
                           .ready
                           .where(updated_at: JUST_IMPORTED_WINDOW.ago..)
                           .order(updated_at: :desc)
                           .first
      course = recent&.course
      return nil unless course&.published?
      return nil if started?(course)

      course
    end

    def started?(course)
      LessonUser.joins(:lesson).where(
        user_id: current_user.id,
        lesson: { course_id: course.id }
      ).exists?
    end

    # Everything on their Home except whatever's already in the hero.
    def candidate_enrollments
      scope = current_user.enrollments
                          .in_progress
                          .includes(course: [ :language, { course_translations: :language } ])
                          .joins(:course)
                          .merge(Course.published)
                          .recently_practiced
      scope = scope.where.not(course_id: @hero_course.id) if @hero_course
      scope.limit(20).to_a
    end

    # Courses from the Library the user hasn't added yet, in their language.
    #
    # Newest first, not random. On first run this grid is the whole screen and
    # its subhead promises "any recently created Langlet" — random picks would
    # have made that copy a lie, and a grid that reshuffles on every visit gives
    # a returning user nothing to recognize. Recency is also the only signal
    # available here; real selection comes later.
    def library_picks(count:)
      scope = ChannelContentQuery.new(user: current_user, language: @learning_language).items
      scope = scope.where.not(course_id: current_user.enrollments.select(:course_id))
      scope = scope.where.not(course_id: @hero_course.id) if @hero_course
      scope.limit(count).to_a
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
