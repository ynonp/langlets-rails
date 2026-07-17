module App
  # Screen 01. The user's own courses (Enrollments — imported or added from the
  # Library), plus a few Library suggestions: four as a first-run song picker
  # when there's nothing to continue, two under "More from the library" otherwise.
  class HomeController < BaseController
    # Within this window a finished import still counts as "just imported" and
    # gets the hero card. Also how the push deep link lands: it routes to
    # /app?just_imported=<slug>.
    JUST_IMPORTED_WINDOW = 48.hours

    def index
      @greeting_name = greeting_name
      @hero_course = hero_course
      @learning_language = Language.find_by(iso_name: current_language_code) if current_language_code.present?
      @playlists = current_user.playlists
                               .includes(courses: [ :language, :translation_language ])
                               .order(updated_at: :desc)
                               .to_a

      candidates = candidate_enrollments
      @lesson_counts = lesson_counts_for(candidates.map(&:course) + [ @hero_course ].compact)
      @completed_counts = completed_counts_for(candidates.map(&:course_id))

      @enrollments = candidates.reject { |enrollment| finished?(enrollment) }

      # First run = nothing to continue and nothing just imported: the screen
      # becomes a song picker instead of a progress list.
      @first_run = @hero_course.nil? && @enrollments.empty?
      @library_picks = library_picks(count: @first_run ? 4 : 2)
      @lesson_counts.merge!(lesson_counts_for(@library_picks))
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

    # Courses from the Library the user hasn't added yet, in their language.
    # Deliberately dumb for now — random picks; real selection comes later.
    def library_picks(count:)
      scope = Course.published.includes(:language, :translation_language)
      scope = scope.where(language: @learning_language) if @learning_language
      scope = scope.where.not(id: current_user.enrollments.select(:course_id))
      scope = scope.where.not(id: @hero_course.id) if @hero_course
      scope.order(Arel.sql("RANDOM()")).limit(count).to_a
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
