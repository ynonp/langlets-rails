class Activity < ApplicationRecord
  belongs_to :lesson
  has_many :activity_phrases, dependent: :destroy
  has_many :phrases, through: :activity_phrases
  has_many :activity_token_translations, dependent: :destroy
  has_many :token_translations, through: :activity_token_translations

  def partial_name
    self.class.name.underscore
  end

  def create_dictionary
    phrases.each do |phrase|
      phrase.create_mappings if phrase.token_translations.empty?
    end
  end


  def video_params
    {
      video_id: lesson.medium.extract_youtube_video_id,
      start_timestamp: phrases.order(timestamp: :asc).first.timestamp,
      end_timestamp: to_string_timestamp(phrases.order(timestamp: :desc).first.timestamp_seconds + 5)
    }
  end

  # convert a timestamp in seconds to a string timestamp format ("MM:SS")
  def to_string_timestamp(timestamp)
    minutes = timestamp / 60
    seconds = timestamp % 60
    "#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end
end
