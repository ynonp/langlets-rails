require "csv"

class PlayerController < ApplicationController
  before_action :set_course
  before_action :set_medium

  def show
    @phrases = load_phrases
    if @phrases.blank?
      redirect_to course_path(@course.slug), alert: "No lyrics available yet."
      return
    end

    @phrases = Phrase.with_calculated_end_timestamps(@phrases, @medium.phrases.ordered_by_timestamp)
    @video_id = @medium.extract_youtube_video_id
    @video_hl = @medium.language&.iso_name || "en"
    @l1_language = @phrases.first.l1
    @l2_language = @phrases.first.l2
    @l1_rtl = @l1_language&.rtl
    @l2_rtl = @l2_language&.rtl
    @song_start_timestamp = @phrases.first.timestamp
    @song_end_timestamp = seconds_to_timestamp(@phrases.last.timestamp_seconds + 5)
    @vocabulary_entries = build_vocabulary_entries(@phrases)

    respond_to do |format|
      format.html
      format.csv do
        send_data vocabulary_csv(@vocabulary_entries),
                  filename: "#{@course.slug}-vocabulary.csv",
                  type: "text/csv"
      end
    end
  end

  private

  def set_course
    @course = Course.includes(lessons: :medium).find_by(slug: params[:slug])
    return if @course

    redirect_to courses_path, alert: "Course not found."
  end

  def set_medium
    return if performed?

    @medium = @course&.lessons&.first&.medium
    @medium ||= Medium.find_by(url: @course.main_media_url)

    return if @medium

    redirect_to course_path(@course.slug), alert: "Course media not available."
  end

  def load_phrases
    return [] unless @medium

    @medium.phrases
           .ordered_by_timestamp
           .includes(:l1, :l2, token_translations: { l1_audio_attachment: :blob })
           .to_a
  end

  def build_vocabulary_entries(phrases)
    tokens = phrases.flat_map(&:token_translations)
    seen = {}

    tokens.each_with_object([]) do |token, memo|
      key = [token.original_text.downcase, token.translation.downcase]
      next if seen[key]

      seen[key] = true
      memo << token
    end.sort_by { |token| [token.phrase.timestamp_seconds, token.l1_start_index] }
  end

  def vocabulary_csv(tokens)
    CSV.generate(headers: true) do |csv|
      csv << ["Word", "Translation", "Phrase", "Timestamp"]
      tokens.each do |token|
        csv << [
          token.original_text,
          token.translation,
          token.phrase.text_l1,
          token.phrase.timestamp
        ]
      end
    end
  end

  def seconds_to_timestamp(seconds)
    minutes = seconds / 60
    secs = seconds % 60
    format("%02d:%02d", minutes, secs)
  end
end
