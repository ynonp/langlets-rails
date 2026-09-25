module Api::V1::Native
  class BaseController < Api::V1::BaseController
    before_action -> { doorkeeper_authorize! :native }
    around_action :with_account_language
    before_action :private_response

    rescue_from ActiveRecord::RecordNotFound do
      render_error(:not_found, "This item is no longer available", :not_found)
    end
    rescue_from ActiveRecord::RecordInvalid do |error|
      render_error(:invalid_record, error.record.errors.full_messages.join(", "), :unprocessable_entity)
    end
    rescue_from ActionController::ParameterMissing, ArgumentError, PhraseTokenUser::InvalidInput, PhraseTokenUser::InputError do |error|
      render_error(:invalid_input, error.message, :unprocessable_entity)
    end

    private

    alias_method :user, :current_resource_owner

    def with_account_language(&block)
      return yield unless doorkeeper_token&.accessible?
      language = user.native_language
      Current.set(translation_language: language) do
        I18n.with_locale(language.iso_name, &block)
      end
    end

    def private_response
      response.headers["Cache-Control"] = "no-store"
    end

    def render_error(code, message, status)
      render json: { error: code, error_description: message }, status: status
    end

    def readable_course(slug = params[:id])
      course = Course.published.find_by!(slug: slug)
      raise ActiveRecord::RecordNotFound unless course.readable_by?(user)
      course
    end

    def readable_lesson(id = params[:id])
      lesson = Lesson.find(id)
      if lesson.course
        raise ActiveRecord::RecordNotFound unless lesson.course.published? && lesson.course.readable_by?(user)
      else
        raise ActiveRecord::RecordNotFound unless lesson.user_id == user.id && lesson.review_language_id.present?
      end
      lesson
    end

    def serializer
      @serializer ||= ::Native::Serializer.new(user: user, base_url: request.base_url)
    end

    def page(scope)
      number = [ params[:page].to_i, 1 ].max
      records = scope.limit(41).offset((number - 1) * 40).to_a
      serializer.prepare_courses(records.first(40)) if records.first.is_a?(Course)
      { items: records.first(40).map { |record| yield(record) }, next_page: records.size > 40 ? number + 1 : nil }
    end
  end
end
