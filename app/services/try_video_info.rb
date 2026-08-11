class TryVideoInfo
  Info = Data.define(:language, :duration, :line_count, :unique_word_count)
  WORD_PATTERN = /[\p{L}\p{M}\p{N}]+/u

  def self.for(video)
    relation = Course.published.includes(:language)
    course = relation.find_by(youtube_video_id: video.video_id) ||
      relation.find_by(main_media_url: video.canonical_url)
    return if course.nil? || course.language.nil?

    medium = course.lessons.where.not(medium_id: nil).includes(:medium).first&.medium ||
      Medium.find_by(url: video.canonical_url, language: course.language)
    return if medium.nil?

    phrases = medium.phrases.order(:id).pluck(:text_l1, :timestamp)
    return if phrases.empty?

    duration_seconds = course.lessons.filter_map { |lesson| timestamp_seconds(lesson.end_timestamp) }.max
    duration_seconds ||= phrases.filter_map { |_text, timestamp| timestamp_seconds(timestamp) }.max&.+(5)
    words = phrases.flat_map { |text, _timestamp| text.to_s.downcase.scan(WORD_PATTERN) }.uniq
    return if duration_seconds.nil? || words.empty?

    Info.new(
      language: course.language.english_name,
      duration: format_duration(duration_seconds),
      line_count: phrases.size,
      unique_word_count: words.size
    )
  end

  def self.timestamp_seconds(timestamp)
    HasTimestamp.timestamp_to_seconds(timestamp)
  end
  private_class_method :timestamp_seconds

  def self.format_duration(seconds)
    total = seconds.round
    minutes, remaining_seconds = total.divmod(60)
    hours, remaining_minutes = minutes.divmod(60)

    return format("%d:%02d:%02d", hours, remaining_minutes, remaining_seconds) if hours.positive?

    format("%d:%02d", minutes, remaining_seconds)
  end
  private_class_method :format_duration
end
