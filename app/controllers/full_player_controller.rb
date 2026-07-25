class FullPlayerController < ApplicationController
  def show
    @course = Course.find_by!(slug: params[:course_slug])
    
    # Check if user has access to the course
    # For now, all authenticated users can view full player if course has the flag enabled
    unless @course.show_full_course_player
      redirect_to course_path(@course.slug), alert: "Full player is not available for this course."
      return
    end

    @first_lesson = @course.lessons.order(:order).first

    # Load all phrases from course's medium ordered by timestamp
    @phrases = @first_lesson.medium.phrases.includes(
      :localized_translation,
      phrase_tokens: [ :localized_translation, { l1_audio_attachment: :blob } ]
    ).order(:timestamp).load
    
    @video_id = @course.video_id
    @video_provider = @course.provider

    # Get start and end timestamps from phrases
    @start_timestamp = @phrases.first&.timestamp || "00:00"
    @end_timestamp = full_player_end_timestamp(@phrases)

    # Karaoke word highlighting is enabled only when tokens carry per-word timestamps.
    @word_timing = helpers.word_timing_enabled?(@phrases)
  end

  private

  def full_player_end_timestamp(phrases)
    token_end_timestamps = phrases.flat_map do |phrase|
      phrase.phrase_tokens.filter_map(&:end_timestamp)
    end

    token_end_timestamps.max_by { |timestamp| Phrase.timestamp_to_seconds(timestamp) } ||
      phrases.last&.timestamp ||
      "00:00"
  end

end
