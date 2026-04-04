class FullPlayerController < ApplicationController
  def show
    @course = Course.find_by!(slug: params[:course_slug])
    
    # Check if user has access to the course
    # For now, all authenticated users can view full player if course has the flag enabled
    unless @course.show_full_course_player
      redirect_to course_path(@course.slug), alert: "Full player is not available for this course."
      return
    end

    # Load all phrases from course's medium ordered by timestamp
    @phrases = @course.medium.phrases.includes(:token_translations).order(:timestamp)
    
    # Extract video_id from course's main_media_url
    @video_id = extract_video_id_from_url(@course.main_media_url)
    
    # Get start and end timestamps from phrases
    @start_timestamp = @phrases.first&.timestamp || "00:00"
    @end_timestamp = @phrases.last&.timestamp || "00:00"
  end

  private

  def extract_video_id_from_url(url)
    # Match patterns like:
    # - https://www.youtube.com/watch?v=VIDEO_ID
    # - https://youtu.be/VIDEO_ID
    # - https://www.youtube.com/shorts/VIDEO_ID
    regex = %r{
      (?:youtube\.com/(?:watch\?v=|shorts/)|
       youtu\.be/)           # Match the base domain and path
      ([\w-]{11})            # Capture the 11-character video ID
    }x
  
    match = url.match(regex)
    match[1] if match
  end
end
