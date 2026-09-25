module Api::V1::Native
  class ChallengesController < BaseController
    def show
      challenge = user.starter_challenge
      quest = challenge&.current_quest
      render json: { enrolled: challenge.present?, language_ids: challenge&.language_ids || [],
        reminder_time: challenge&.reminder_time || "09:00", reminder_timezone: challenge&.reminder_timezone || "UTC",
        first_challenge_on: challenge&.first_challenge_on, practice_started: challenge&.practice_started? || false,
        quest: quest && { day: quest.day, kind: quest.quest, completed: quest.completed_at.present? } }
    end

    def update
      StarterChallenge.enroll!(user: user, language_ids: params[:language_ids],
        delivery: params.fetch(:notification_delivery, user.notification_delivery),
        reminder_time: params[:reminder_time], reminder_timezone: params[:reminder_timezone])
      SendDailyChallengesJob.perform_later
      show
    end
  end
end
