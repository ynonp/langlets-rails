class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :omniauthable,
         omniauth_providers: [:google_oauth2, :github]

  has_many :lesson_users, dependent: :destroy
  has_many :completed_lessons, through: :lesson_users, source: :lesson
  
  has_many :activity_users, dependent: :destroy
  has_many :completed_activities, through: :activity_users, source: :activity

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
end
