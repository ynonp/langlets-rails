class ProgressController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :sync_local_xp]
  
  def create
    xp_awarded = 0
    
    # Handle XP awarding for both authenticated and unauthenticated users
    if params[:xp].present?
      xp_awarded = params[:xp].to_i
      
      if current_user
        user_stats = UserGameStat.for_user(current_user)
        user_stats.add_xp(xp_awarded)
        @user_stats = user_stats
      end
    end
    
    # Handle activity/lesson completion for authenticated users
    if current_user
      if params[:activity_id].present?
        mark_activity_completed(params[:activity_id])
      end
      
      if params[:lesson_id].present?
        mark_lesson_completed(params[:lesson_id])
      end
    end
    
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace("gamification-bar", 
          partial: "lessons/gamification_bar", 
          locals: { 
            user_stats: @user_stats,
            xp_awarded: xp_awarded,
            current_user: current_user
          })
      }
      format.json { render json: { status: 'success', xp_awarded: xp_awarded } }
      format.html { head :ok }
    end
  end

  def sync_local_xp
    return head :unauthorized unless current_user

    local_xp_data = JSON.parse(request.body.read)
    current_user.sync_local_xp(local_xp_data)
    @user_stats = UserGameStat.for_user(current_user)
    
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace("gamification-bar", 
          partial: "lessons/gamification_bar", 
          locals: { 
            user_stats: @user_stats,
            current_user: current_user
          })
      }
      format.json { render json: { status: 'success' } }
    end
  rescue JSON::ParserError
    render json: { status: 'error', message: 'Invalid JSON' }, status: 400
  end
  
  private
  
  def mark_activity_completed(activity_id)
    activity = Activity.find(activity_id)
    ActivityUser.find_or_create_by(
      activity: activity,
      user: current_user
    )
    activity
  end
  
  def mark_lesson_completed(lesson_id)
    lesson = Lesson.find(lesson_id)
    LessonUser.find_or_create_by(
      lesson: lesson,
      user: current_user
    )
  end
end