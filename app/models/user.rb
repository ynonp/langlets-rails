class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :omniauthable

  has_many :lesson_users, dependent: :destroy
  has_many :completed_lessons, through: :lesson_users, source: :lesson
  
  has_many :activity_users, dependent: :destroy
  has_many :completed_activities, through: :activity_users, source: :activity
end
