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
    progress.reload
    
    # Broadcast progress update
    broadcast_progress_update(progress, course)
    
    course.reload

    builder = CourseBuilder::BuildSong.new(progress, course)
    builder.call

    course.published!
    
    # Broadcast completion
    broadcast_progress_update(progress, course, completed: true)
    
    CourseMailer.creation_complete(course).deliver_now
  end

  def broadcast_progress_update(progress, course, completed: false)
    CreateSongProgressChannel.broadcast_to(
      progress,
      {
        progress_html: ApplicationController.render(
          partial: 'create_song_progresses/progress_steps',
          locals: { progress: progress }
        ),
        content_html: ApplicationController.render(
          partial: 'create_song_progresses/content_display',
          locals: { progress: progress, course: course }
        ),
        completed: completed,
        course_url: completed ? Rails.application.routes.url_helpers.course_path(course) : nil
      }
    )
  end
end
