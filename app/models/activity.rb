class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :lesson
  has_many :activity_phrases, dependent: :destroy
  has_many :phrases, through: :activity_phrases
  has_many :activity_token_translations, dependent: :destroy
  has_many :token_translations, through: :activity_token_translations

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
    when 'WatchVideoActivity'
      10 # Single stage activity
    when 'MatchPhrasesActivity', 'MatchTokensActivity'
      # Multi-stage activities: 2 XP per correct answer
      # Base on number of items to match
      phrases.count * 2
    when 'SortPhrasesActivity'
      phrases.count * 2
    when 'LanguageAlignmentActivity'
      token_translations.count * 2
    when 'SpeakActivity', 'ListenActivity'
      phrases.count * 2
    when 'FindAnswerActivity'
      phrases.count * 2
    when 'WordOrderActivity'
      phrases.count * 2
    else
      10 # Default for new activity types
    end
  end

  def partial_name
    self.class.name.underscore
  end

  def create_dictionary
    phrases.each do |phrase|
      phrase.create_mappings if phrase.token_translations.empty?
    end
  end

  def ordered_phrases
    @ordered_phrases ||= phrases
      .ordered_by_timestamp
      .includes(
        :l1, :l2,  # Include languages to prevent N+1 queries
        { text_l1: { script_variants: :script } },
        { text_l2: { script_variants: :script } },
        { token_translations: [
          { l1_audio_attachment: :blob },
          { phrase: [
            :l1, :l2,
            { text_l1: { script_variants: :script } },
            { text_l2: { script_variants: :script } }
          ]}
        ]}
      )
      .to_a
  end

  def video_params
    {
      video_id: lesson.medium.extract_youtube_video_id,
      start_timestamp: ordered_phrases.first&.timestamp,
      end_timestamp: to_string_timestamp(ordered_phrases.last&.timestamp_seconds + 5)
    }
  end

  # convert a timestamp in seconds to a string timestamp format ("MM:SS")
  def to_string_timestamp(timestamp)
    minutes = timestamp / 60
    seconds = timestamp % 60
    "#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end
end
