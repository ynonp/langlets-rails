class ProgressController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :sync_local_xp, :log]
  
  def create
    xp_awarded = 0
    
    # Handle XP awarding for both authenticated and unauthenticated users
    if params[:xp].present?
      xp_awarded = params[:xp].to_i
      
      if current_user
        # Create activity log entry for XP gain
        active_time = params[:active_time]&.to_i || 0
        ActivityLog.log_activity_completion(
          user: current_user,
          active_time: active_time,
          xp_gained: xp_awarded
        )
        
        # Calculate current stats for display
        @daily_xp = ActivityLog.daily_xp_for_user(current_user)
        @total_xp = ActivityLog.total_xp_for_user(current_user)
        @current_streak = ActivityLog.current_streak_for_user(current_user)
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
            daily_xp: @daily_xp,
            total_xp: @total_xp,
            current_streak: @current_streak,
            xp_awarded: xp_awarded,
            current_user: current_user
          })
      }
      format.json { render json: { status: 'success', xp_awarded: xp_awarded } }
      format.html { head :ok }
    end
  end
  
  # New endpoint for logging activity with time tracking
  def log
    return head :ok unless current_user
    
    active_time = params[:active_time]&.to_i || 0
    xp_gained = params[:xp_gained]&.to_i || 0
    
    if params[:lesson_id].present?
      # Lesson completion log
      lesson = Lesson.find(params[:lesson_id])
      ActivityLog.log_lesson_completion(
        user: current_user,
        lesson: lesson,
        active_time: active_time,
        xp_gained: xp_gained
      )
    elsif xp_gained > 0
      # Activity completion log
      ActivityLog.log_activity_completion(
        user: current_user,
        active_time: active_time,
        xp_gained: xp_gained
      )
    end
    
    head :ok
  end

  def sync_local_xp
    return head :unauthorized unless current_user

    local_xp_data = JSON.parse(request.body.read)
    
    # Sync local XP data to ActivityLog
    if local_xp_data['dailyXp'] && local_xp_data['dailyXp'] > 0
      ActivityLog.log_activity_completion(
        user: current_user,
        active_time: 0, # No time tracking for synced XP
        xp_gained: local_xp_data['dailyXp']
      )
    end
    
    # Calculate current stats for display
    @daily_xp = ActivityLog.daily_xp_for_user(current_user)
    @total_xp = ActivityLog.total_xp_for_user(current_user)
    @current_streak = ActivityLog.current_streak_for_user(current_user)
    
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace("gamification-bar", 
          partial: "lessons/gamification_bar", 
          locals: { 
            daily_xp: @daily_xp,
            total_xp: @total_xp,
            current_streak: @current_streak,
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
    
    # Log lesson completion with XP and time
    active_time = params[:active_time]&.to_i || 0
    xp_gained = params[:lesson_xp]&.to_i || 0
    
    ActivityLog.log_lesson_completion(
      user: current_user,
      lesson: lesson,
      active_time: active_time,
      xp_gained: xp_gained
    )
  end
  
end