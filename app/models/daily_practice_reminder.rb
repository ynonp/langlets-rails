class DailyPracticeReminder < ApplicationRecord
  belongs_to :starter_challenge
  belongs_to :notification
  validates :local_date, presence: true, uniqueness: { scope: :starter_challenge_id }
end
