class ActivityUser < ApplicationRecord
  belongs_to :activity
  belongs_to :user
  
  validates :activity_id, uniqueness: { scope: :user_id }
end
