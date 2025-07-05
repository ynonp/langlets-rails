class CreateCourseJob < ApplicationJob
  queue_as :default

  def perform(create_song_progress_id, course_id)
    progress = CreateSongProgress.find(create_song_progress_id)
    course = Course.find(course_id)
    
    begin
      # Extract lesson template from the progress data
      lesson_template = progress.data&.dig('lesson_template') || 'create_song'
      
      # Create the AI song generator using values from the progress record
      cs = Ai::CreateSong.new(
        course.name, 
        progress.youtubeurl, 
        progress.clip_language, 
        progress.translation_language, 
      )
      cs.run
      
      # The AI service will update the same progress record we created,
      # since it uses find_or_create_by with the same parameters
      progress.reload
      course.reload
      
      if progress.ready?
        # Create the course content based on template
        case lesson_template
        when 'song'
          course.create_song!(progress)
        when 'short'
          course.create_short!(progress)
        else
          course.create_song!(progress)
        end
        
        # Mark course as published
        course.update!(status: :published)
        
        # Send completion email
        CourseMailer.creation_complete(course).deliver_now
      else
        raise "Course creation failed - progress not ready"
      end
      
    rescue => e
      Rails.logger.error "Course creation failed for course #{course_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Send failure email
      CourseMailer.creation_failed(course, e.message).deliver_now
      raise e
    end
  end
end
