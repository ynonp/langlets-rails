class ProspectsController < ApplicationController
  include CourseReadable

  rate_limit to: 10, within: 1.hour, by: -> { request.remote_ip }, only: :create,
    with: -> { render plain: I18n.t("marketing.rate_limit"), status: :too_many_requests }

  def create
    @course = Course.find_by!(slug: params[:course_id])
    return unless authorize_course_read!(@course)
    @lesson = @course.lessons.find_by!(slug: params[:lesson_id])
    return head :not_found unless marketing_visit?
    email = Channel.normalize_email(params.dig(:prospect, :email))
    prospect = Prospect.create_or_find_by!(email: email) do |record|
      record.assign_attributes(utm_source: session[:utm_source], course: @course, lesson: @lesson, locale: I18n.locale.to_s)
    end
    DeliverProspectEmailsJob.perform_later(prospect.id)
    session.delete(:utm_source)
    flash[:prospect_submitted] = true
    redirect_to finish_course_lesson_path(@course, @lesson), notice: t("marketing.check_email"), status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to finish_course_lesson_path(@course, @lesson), alert: t("marketing.invalid_email"), status: :see_other
  end
end
