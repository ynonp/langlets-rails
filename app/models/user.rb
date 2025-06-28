class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :omniauthable,
         omniauth_providers: [:google_oauth2, :github]

  # Ownership relationships
  has_many :courses, dependent: :destroy
  has_many :lessons, dependent: :destroy
  has_many :activities, dependent: :destroy

  # Progress tracking relationships
  has_many :lesson_users, dependent: :destroy
  has_many :completed_lessons, through: :lesson_users, source: :lesson
  
  has_many :activity_users, dependent: :destroy
  has_many :completed_activities, through: :activity_users, source: :activity

  # Gamification relationship
  has_one :user_game_stat, dependent: :destroy

  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize do |new_user|
      new_user.email = auth.info.email
      new_user.password = Devise.friendly_token[0, 20]
      # new_user.name = auth.info.name # if you have a name field
      new_user.provider = auth.provider
      new_user.uid = auth.uid
      new_user.confirmed_at = Time.current
    end
    
    # Update provider and uid for existing users logging in with different OAuth provider
    if user.persisted? && (user.provider != auth.provider || user.uid != auth.uid)
      user.update(provider: auth.provider, uid: auth.uid)
    end
    
    # Save if new record
    user.save if user.new_record?
    
    user
  end  

  def recommended_for_me
    Course.none
  end

  def sync_local_xp(local_xp_data)
    return unless local_xp_data.is_a?(Hash) && local_xp_data['dailyXp'].present?
    
    user_stats = UserGameStat.for_user(self)
    daily_xp = local_xp_data['dailyXp'].to_i
    
    # Only sync if the local XP is from today
    local_date = local_xp_data['date']
    if local_date == Date.current.to_s || local_date == Date.current.strftime('%a %b %d %Y')
      user_stats.add_xp(daily_xp)
    end
  end
end
