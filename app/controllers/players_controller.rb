require "csv"

class PlayersController < ApplicationController
  include ActivitiesHelper

  def show
    @course = Course.find_by(slug: params[:slug])

    unless @course
      redirect_to root_path, alert: "Course not found"
      return
    end

    # Get the medium from the first lesson
    @medium = @course.lessons.first&.medium

    unless @medium
      redirect_to root_path, alert: "Course has no media content"
      return
    end

    # Get all phrases from the medium ordered by timestamp
    @phrases = @medium.phrases.includes(:token_translations, :l1, :l2).ordered_by_timestamp

    # Extract video ID
    @videoid = @medium.extract_youtube_video_id

    # Get language info from the first phrase
    first_phrase = @phrases.first
    @l1_rtl = first_phrase&.l1&.rtl || false
    @l2_rtl = first_phrase&.l2&.rtl || false
    @l1_name = first_phrase&.l1&.iso_name || "en"

    # Collect all unique token translations for vocabulary
    @vocabulary = collect_vocabulary(@phrases)
  end

  def vocabulary_csv
    @course = Course.find_by(slug: params[:slug])

    unless @course
      head :not_found
      return
    end

    @medium = @course.lessons.first&.medium

    unless @medium
      head :not_found
      return
    end

    @phrases = @medium.phrases.includes(:token_translations).ordered_by_timestamp
    @vocabulary = collect_vocabulary(@phrases)

    csv_data = generate_vocabulary_csv(@vocabulary)

    send_data csv_data,
              filename: "#{@course.slug}-vocabulary.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def collect_vocabulary(phrases)
    seen = Set.new
    vocabulary = []

    phrases.each do |phrase|
      phrase.token_translations.each do |tt|
        original_text = token_original_text(tt)
        next if original_text.blank? || tt.translation.blank?

        key = "#{original_text.downcase}|#{tt.translation.downcase}"
        next if seen.include?(key)

        seen.add(key)
        vocabulary << {
          word: original_text,
          definition: tt.translation
        }
      end
    end

    vocabulary
  end

  def generate_vocabulary_csv(vocabulary)
    CSV.generate(headers: true) do |csv|
      csv << ["Word", "Definition"]
      vocabulary.each do |item|
        csv << [item[:word], item[:definition]]
      end
    end
  end
end
