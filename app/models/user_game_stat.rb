class UserGameStat < ApplicationRecord
  belongs_to :user

  validates :total_xp, :current_streak, :daily_xp, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def self.for_user(user)
    find_or_create_by(user: user)
  end

  def add_xp(amount)
    today = Time.zone.now.to_date
    
    # Reset daily XP if it's a new day
    if last_activity_date != today
      self.daily_xp = 0
    end
    
    # Add XP
    self.total_xp += amount
    self.daily_xp += amount
    self.last_activity_date = today
    
    save!
  end

  def add_streak_if_first_lesson_today
    today = Time.zone.now.to_date
    
    # Only add to streak if this is the first lesson completed today
    if last_activity_date != today
      self.current_streak += 1
      self.last_activity_date = today
      save!
    end
  end

  def reset_streak_if_missed_day
    today = Time.zone.now.to_date
    return if last_activity_date.nil?
    
    # If more than 1 day has passed since last activity, reset streak
    if (today - last_activity_date).to_i > 1
      self.current_streak = 0
      save!
    end
  end
end