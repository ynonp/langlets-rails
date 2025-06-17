class ProgressController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def create
    return head :unauthorized unless current_user
    
    if params[:activity_id].present?
      mark_activity_completed(params[:activity_id])
    end
    
    if params[:lesson_id].present?
      mark_lesson_completed(params[:lesson_id])
    end
    
    head :ok
  end
  
  private
  
  def mark_activity_completed(activity_id)
    activity = Activity.find(activity_id)
    ActivityUser.find_or_create_by(
      activity: activity,
      user: current_user
    )
  end
  
  def mark_lesson_completed(lesson_id)
    lesson = Lesson.find(lesson_id)
    LessonUser.find_or_create_by(
      lesson: lesson,
      user: current_user
    )
  end
end