class ReviewLessonBuildsController < ApplicationController
  before_action :authenticate_user!

  def show
    @review_lesson_build = current_user.review_lesson_builds.find_by!(
      request_id: params[:id]
    )

    return redirect_to review_lesson_path(@review_lesson_build.lesson) if @review_lesson_build.ready?
    return render "review_lessons/failed" if @review_lesson_build.failed?

    render "review_lessons/waiting"
  end
end
