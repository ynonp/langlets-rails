class DailyPracticeReminder < ApplicationRecord
  belongs_to :starter_challenge
  belongs_to :notification
  validates :local_date, presence: true, uniqueness: { scope: :starter_challenge_id }

  def self.deliver_due!(challenge)
    challenge.with_lock do
      date = challenge.local_today
      return unless challenge.practice_started?
      if Time.zone.now < challenge.local_time_on(date)
        challenge.update!(next_practice_at: challenge.local_time_on(date))
        return
      end
      if challenge.daily_practice_reminders.exists?(local_date: date)
        challenge.update!(next_practice_at: challenge.local_time_on(date + 1))
        return
      end

      language = challenge.practice_language
      notification = Notifications.deliver(user: challenge.user, kind: :daily_practice,
        language_code: language.iso_name, language_name: language.english_name)
      challenge.daily_practice_reminders.create!(local_date: date, notification: notification)
      challenge.update!(next_practice_at: challenge.local_time_on(date + 1))
    end
  end
end
