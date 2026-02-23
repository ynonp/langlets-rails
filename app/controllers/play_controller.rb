class PlayController < ApplicationController
  def show
    @course = Course.find_by(slug: params[:slug])

    unless @course
      redirect_to root_path, alert: "Course not found"
      return
    end

    # Get the medium from the first lesson to access phrases
    first_lesson = @course.lessons.first
    unless first_lesson
      redirect_to root_path, alert: "No lessons found for this course"
      return
    end

    @medium = first_lesson.medium

    # Get all phrases for the medium ordered by timestamp
    @phrases = @medium.phrases
                     .includes(:token_translations, :l1, :l2)
                     .ordered_by_timestamp

    # Get RTL settings from languages
    @l1 = @phrases.first&.l1
    @l2 = @phrases.first&.l2
    @l1_rtl = @l1&.rtl || false
    @l2_rtl = @l2&.rtl || false

    # Get video ID
    @videoid = @medium.extract_youtube_video_id

    # Prepare vocabulary data - all token translations from the medium
    @vocabulary = @phrases.flat_map(&:token_translations).uniq { |tt| [tt.original_text.downcase, tt.translation.downcase] }
  end

  def vocabulary_csv
    @course = Course.find_by(slug: params[:slug])

    unless @course
      head :not_found
      return
    end

    first_lesson = @course.lessons.first
    unless first_lesson
      head :not_found
      return
    end

    medium = first_lesson.medium
    phrases = medium.phrases.includes(:token_translations)
    vocabulary = phrases.flat_map(&:token_translations).uniq { |tt| [tt.original_text.downcase, tt.translation.downcase] }

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Word", "Translation"]
      vocabulary.each do |tt|
        csv << [tt.original_text, tt.translation]
      end
    end

    send_data csv_data,
              filename: "#{@course.slug}-vocabulary.csv",
              type: "text/csv",
              disposition: "attachment"
  end
end
