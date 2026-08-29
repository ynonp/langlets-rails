class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :lesson
  has_many :activity_phrases, dependent: :destroy
  has_many :phrases, through: :activity_phrases
  has_many :activity_phrase_tokens, dependent: :destroy
  has_many :phrase_tokens, through: :activity_phrase_tokens

  has_many :activity_users, dependent: :destroy
  has_many :users_completed, through: :activity_users, source: :user

  def completed_by?(user)
    return false unless user
    activity_users.exists?(user: user)
  end

  def is_last_in_lesson?
    lesson.activities.order(:order).last == self
  end

  def xp_value
    case self.class.name
    when "WatchVideoActivity"
      10 # Single stage activity
    when "MatchPhrasesActivity", "MatchTokensActivity"
      # Multi-stage activities: 2 XP per correct answer
      # Base on number of items to match
      phrases.count * 2
    when "SortPhrasesActivity"
      phrases.count * 2
    when "LanguageAlignmentActivity"
      phrase_tokens.count * 2
    when "SpeakActivity", "ListenActivity"
      phrases.count * 2
    when "FindAnswerActivity"
      phrases.count * 2
    when "WordOrderActivity"
      phrases.count * 2
    when "Activities::WriteMissingWordActivity"
      phrase_tokens.count * 2
    else
      10 # Default for new activity types
    end
  end

  def partial_name
    self.class.name.underscore
  end

  def create_dictionary
    phrases.each do |phrase|
      phrase.create_mappings if phrase.phrase_tokens.empty?
    end
  end

  def ordered_phrases
    @ordered_phrases ||= phrases
      .ordered_by_timestamp
      .includes(:localized_translation, phrase_tokens: [ :localized_translation, { l1_audio_attachment: :blob } ])
      .to_a
  end

  def video_params
    {
      video_id: Medium.new(url: lesson.media_url).extract_youtube_video_id,
      start_timestamp: ordered_phrases.first&.timestamp,
      end_timestamp: lesson.end_timestamp || to_string_timestamp(ordered_phrases.last&.timestamp_seconds + 5)
    }
  end

  # convert a timestamp in seconds to a string timestamp format ("MM:SS")
  def to_string_timestamp(timestamp)
    total_seconds = timestamp.to_f
    minutes = total_seconds.to_i / 60
    seconds = total_seconds % 60
    format("%02d:%05.2f", minutes, seconds)
  end
end
