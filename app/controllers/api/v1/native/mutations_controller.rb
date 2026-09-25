require "digest"

module Api::V1::Native
  class MutationsController < BaseController
    def create
      operation_id = params.require(:operation_id).to_s
      raise ArgumentError, "operation_id must be a UUID" unless operation_id.match?(/\A[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i)
      payload = params.require(:payload).permit(:kind, :lesson_id, :activity_id, :token_id, :entry_id,
        :practicing, :sentence, :language, :token_start, :token_end, :translation, :notification_id, :day, :occurred_at).to_h
      digest = Digest::SHA256.hexdigest(JSON.generate(payload.sort.to_h))
      result = user.with_lock do
        receipt = NativeMutationReceipt.find_by(user: user, operation_id: operation_id)
        if receipt
          if receipt.payload_digest != digest
            return render_error(:operation_conflict, "An operation ID cannot be reused for different data", :conflict)
          end
          receipt.result
        else
          value = apply(payload)
          NativeMutationReceipt.create!(user: user, operation_id: operation_id, payload_digest: digest, result: value)
          value
        end
      end
      render json: { operation_id: operation_id, result: result }
    end

    private

    def apply(data)
      occurred_at = data["occurred_at"].present? ? Time.iso8601(data["occurred_at"]).in_time_zone : Time.zone.now
      occurred_at = occurred_at.clamp(7.days.ago, Time.zone.now)
      case data.fetch("kind")
      when "activity_complete"
        activity = Activity.find(data.fetch("activity_id"))
        readable_lesson(activity.lesson_id)
        completion = user.activity_users.find_or_create_by!(activity: activity) { |row| row.created_at = occurred_at }
        if completion.previously_new_record?
          ActivityLog.create!(user: user, active_time: 0, xp_gained: activity.xp_value, created_at: occurred_at)
        end
        { completed: true }
      when "lesson_complete"
        lesson = readable_lesson(data.fetch("lesson_id"))
        completion = user.lesson_users.find_or_create_by!(lesson: lesson) { |row| row.created_at = occurred_at }
        if completion.previously_new_record?
          ActivityLog.create!(user: user, lesson: lesson, active_time: 0, xp_gained: 10, created_at: occurred_at)
          if lesson.review_language_id
            lesson.update!(review_build_status: :finished)
            user.refresh_review_lesson!(lesson.review_language)
          end
        end
        { completed: true }
      when "word_save"
        token = accessible_token(data.fetch("token_id"))
        entry = user.phrase_token_users.find_or_create_by!(phrase_token: token)
        { entry_id: entry.id }
      when "word_remove"
        user.phrase_token_users.where(phrase_token_id: data.fetch("token_id")).destroy_all
        { removed: true }
      when "word_update"
        entry = user.phrase_token_users.find(data.fetch("entry_id"))
        if data.key?("practicing")
          raise ArgumentError, "practicing must be boolean" unless [ true, false ].include?(data["practicing"])
          entry.update!(practicing: data["practicing"])
        end
        if data.key?("translation")
          # Match the existing vocabulary editor: the owned saved link authorizes this correction.
          translation = entry.phrase_token.token_translations.find_or_initialize_by(language_id: entry.language_id)
          translation.update!(translation: data["translation"].to_s.strip)
        end
        { entry_id: entry.id }
      when "word_create"
        entry = PhraseTokenUser.create_custom!(user: user, sentence: data.fetch("sentence"),
          language: Language.find_by!(iso_name: data.fetch("language")),
          token_range: Integer(data.fetch("token_start"))..Integer(data.fetch("token_end")),
          translation: data.fetch("translation"))
        { entry_id: entry.id }
      when "notification_read"
        scope = user.notifications
        scope = scope.where(id: data.fetch("notification_id")) if data["notification_id"]
        scope.where(read_at: nil).update_all(read_at: Time.zone.now)
        { read: true }
      when "challenge_complete"
        quest = user.starter_challenge&.daily_challenges&.find_by!(day: data.fetch("day"))
        raise ActiveRecord::RecordNotFound unless quest
        quest.complete!
        { completed: true }
      else
        raise ArgumentError, "Unknown mutation kind"
      end
    rescue KeyError
      raise ArgumentError, "Missing mutation field"
    end

    def accessible_token(id)
      token = PhraseToken.find(id)
      return token if user.phrase_token_users.exists?(phrase_token: token)
      phrase = token.phrase
      return token if phrase.user_id == user.id
      if phrase.medium_id && ChannelContentQuery.courses_visible_to(user).published
        .where(id: Lesson.where(medium_id: phrase.medium_id).select(:course_id)).exists?
        return token
      end
      raise ActiveRecord::RecordNotFound
    end
  end
end
