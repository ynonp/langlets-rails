module Api::V1::Native
  class LessonsController < BaseController
    def show
      render json: serializer.lesson(readable_lesson)
    end

    def review
      language = Language.find_by!(iso_name: params[:language])
      raise ActiveRecord::RecordNotFound unless user.languages_with_saved_words.exists?(id: language.id)
      lesson = user.current_review_lesson(language.iso_name)
      raise ActiveRecord::RecordNotFound unless lesson
      lesson.update!(review_build_status: :started) if lesson.review_pending?
      render json: serializer.lesson(lesson)
    end
  end
end
