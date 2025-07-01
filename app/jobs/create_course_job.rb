class CreateCourseJob < ApplicationJob
  queue_as :default

  def perform(course_id, youtube_url, clip_language, translation_language, lyrics_url, lesson_template)
    course = Course.find(course_id)
    
    begin
      # Create the AI song generator
      cs = Ai::CreateSong.new(course.name, youtube_url, clip_language, translation_language, lyrics_url)
      cs.run
      
      # Find the progress record created by the AI service
      progress = CreateSongProgress.find_by(
        youtubeurl: youtube_url,
        clip_language: clip_language,
        translation_language: translation_language
      )
      
      if progress&.ready?
        # Create the course content based on template
        case lesson_template
        when 'song'
          course.create_song!(progress)
        when 'short'
          course.create_short!(progress)
        else
          raise "Unknown lesson template: #{lesson_template}"
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
