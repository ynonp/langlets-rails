class CreateCourseJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, course_id)
    progress = CreateSongProgress.find(create_song_progress_id)
    course = Course.find(course_id)

    course_created = course.process do |course|
      Rails.logger.info "Starting CreateCourseJob #{create_song_progress_id} / #{course_id}"
      create_course_from_progress(progress, course)
    end

    Rails.logger.info "Another job already processing or completed CreateSongProgress #{create_song_progress_id} / #{course_id}" unless course_created

  rescue => e
    course.error!

    Rails.logger.error "Course creation failed for course #{course.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Send failure email
    CourseMailer.creation_failed(course, e.message).deliver_now
    raise e
  end

  private

  def create_course_from_progress(progress, course)
    progress.create_data
    progress.add_hebrew_script if course.hebrew_script_available
    progress.reload
    course.reload

    builder = CourseBuilder::BuildSong.new(progress, course)
    builder.call

    course.published!
    CourseMailer.creation_complete(course).deliver_now
  end
end
