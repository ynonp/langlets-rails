class PlayController < ApplicationController
  def show
    @course = Course.find_by(slug: params[:slug])
    
    unless @course
      redirect_to root_path, alert: "Course not found"
      return
    end

    # Get the first lesson to extract medium info
    first_lesson = @course.lessons.includes(:medium).order(:order).first
    
    unless first_lesson
      redirect_to root_path, alert: "Course has no lessons"
      return
    end

    @medium = first_lesson.medium
    @videoid = @medium.extract_youtube_video_id
    
    # Get all phrases for the song with their token translations
    @phrases = @medium.phrases.includes(:token_translations, :l1, :l2).ordered_by_timestamp
    
    # Get language info
    first_phrase = @phrases.first
    if first_phrase
      @l1_rtl = first_phrase.l1&.rtl
      @l2_rtl = first_phrase.l2&.rtl
      @l1_name = first_phrase.l1&.iso_name
    else
      @l1_rtl = false
      @l2_rtl = false
      @l1_name = nil
    end

    # Prepare vocabulary data for the vocabulary tab
    @vocabulary = @phrases.flat_map do |phrase|
      phrase.token_translations.map do |tt|
        {
          word: tt.original_text,
          translation: tt.translation,
          phrase_context: phrase.text_l1
        }
      end
    end.uniq { |v| v[:word].downcase }
  end

  def vocabulary_csv
    @course = Course.find_by(slug: params[:slug])
    
    unless @course
      head :not_found
      return
    end

    first_lesson = @course.lessons.includes(:medium).order(:order).first
    
    unless first_lesson
      head :not_found
      return
    end

    @medium = first_lesson.medium
    phrases = @medium.phrases.includes(:token_translations).ordered_by_timestamp

    vocabulary = phrases.flat_map do |phrase|
      phrase.token_translations.map do |tt|
        {
          word: tt.original_text,
          translation: tt.translation
        }
      end
    end.uniq { |v| v[:word].downcase }

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Word", "Translation"]
      vocabulary.each do |v|
        csv << [v[:word], v[:translation]]
      end
    end

    send_data csv_data, filename: "#{@course.slug}-vocabulary.csv", type: "text/csv"
  end
end
