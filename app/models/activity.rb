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
      end_timestamp: phrases.order(timestamp: :desc).first.timestamp,
    }
  end
end
