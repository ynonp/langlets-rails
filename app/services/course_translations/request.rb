module CourseTranslations
  # Requests one additional L2 for an already-published course. This is not an
  # import: it creates no ImportRequest, Enrollment, or ChannelItem and never
  # reaches Channel#publish!, so it cannot spend a credit or republish content.
  class Request
    def self.call(...) = new(...).call

    def initialize(course:, language:)
      @course = course
      @language = language
    end

    def call
      raise ArgumentError, "translation language is missing" if language.nil?
      raise ArgumentError, "translation language matches course language" if course.language_id == language.id

      translation = nil

      ApplicationRecord.transaction do
        progress = course.create_song_progress || CreateSongProgress.find_or_create_by!(
          youtubeurl: course.main_media_url,
          clip_language: course.language&.english_name
        ) { |row| row.data = {} }
        course.update!(create_song_progress: progress) unless course.create_song_progress_id == progress.id

        translation = course.course_translations.find_or_initialize_by(language: language)
        unless translation.ready? || (translation.persisted? && translation.pending?)
          translation.name = course.name
          translation.status = :pending
          translation.save!
          # Solid Queue shares PostgreSQL with the app, so enqueue in the same
          # transaction as its durable pending marker. They commit together.
          AddCourseTranslationJob.perform_later(progress.id, course.id, language.id)
        end
      end

      translation
    end

    private

    attr_reader :course, :language
  end
end
