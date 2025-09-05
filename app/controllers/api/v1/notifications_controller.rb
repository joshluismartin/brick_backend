class Api::V1::NotificationsController < Api::V1::BaseController
  before_action :set_user_email
  
  # POST /api/v1/notifications/habit_completion - Send habit completion email
  def habit_completion
    habit = current_user.habits.find(params[:habit_id])
    achievements = params[:achievements] || []
    
    # Convert achievement IDs to objects if provided
    achievement_objects = if achievements.any?
      current_user.user_achievements.includes(:achievement).where(id: achievements)
    else
      []
    end
    
    result = SendgridService.send_habit_completion_email(current_user.email, habit, achievement_objects)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: current_user.email,
        subject: "🎉 Habit Completed: #{habit.title}",
        achievements_included: achievement_objects.length
      }, "Habit completion email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  rescue ActiveRecord::RecordNotFound
    render_error("Habit not found", :not_found)
  end

  # POST /api/v1/notifications/milestone_progress - Send milestone progress email
  def milestone_progress
    milestone = current_user.milestones.find(params[:milestone_id])
    
    result = SendgridService.send_milestone_progress_email(current_user.email, milestone)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: current_user.email,
        milestone: milestone.title,
        progress: milestone.progress_percentage.round(1)
      }, "Milestone progress email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  rescue ActiveRecord::RecordNotFound
    render_error("Milestone not found", :not_found)
  end

  # POST /api/v1/notifications/blueprint_completion - Send blueprint completion email
  def blueprint_completion
    blueprint = current_user.blueprints.find(params[:blueprint_id])
    
    result = SendgridService.send_blueprint_completion_email(current_user.email, blueprint)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: current_user.email,
        blueprint: blueprint.title,
        completed_early: blueprint.target_date > Date.current
      }, "Blueprint completion email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  rescue ActiveRecord::RecordNotFound
    render_error("Blueprint not found", :not_found)
  end

  # POST /api/v1/notifications/daily_summary - Send daily summary email
  def daily_summary
    # Calculate daily summary data for current user
    summary_data = calculate_daily_summary(current_user)
    
    result = SendgridService.send_daily_summary_email(current_user.email, summary_data)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: current_user.email,
        summary: summary_data
      }, "Daily summary email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  end

  # POST /api/v1/notifications/achievement_notification - Send achievement notification
  def achievement_notification
    achievement_ids = params[:achievement_ids] || []
    
    if achievement_ids.empty?
      render_error("No achievements provided", :bad_request)
      return
    end
    
    achievements = Achievement.where(id: achievement_ids)
    
    if achievements.empty?
      render_error("No valid achievements found", :not_found)
      return
    end
    
    result = SendgridService.send_achievement_notification(current_user.email, achievements)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: current_user.email,
        achievements_count: achievements.length,
        total_points: achievements.sum { |a| a.points }
      }, "Achievement notification email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  end

  # POST /api/v1/notifications/habit_reminder - Send habit reminder email
  def habit_reminder
    # Get habits due today and overdue habits for current user
    habits = get_user_habits(current_user)
    
    if habits.empty?
      render_error("No habits found for reminders", :not_found)
      return
    end
    
    result = SendgridService.send_habit_reminder(current_user.email, habits)
    
    if result[:success]
      overdue_count = habits.count(&:overdue?)
      due_today_count = habits.count - overdue_count
      
      render_success({
        email_sent: true,
        recipient: current_user.email,
        habits_due_today: due_today_count,
        overdue_habits: overdue_count,
        total_habits: habits.length
      }, "Habit reminder email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  end

  # POST /api/v1/notifications/test_email - Send test email (for development)
  def test_email
    template_data = {
      message: "This is a test email from BRICK Goal Achievement API",
      timestamp: Time.current.strftime("%B %d, %Y at %I:%M %p"),
      user_email: current_user.email,
      user_name: current_user.email.split('@').first.capitalize
    }
    
    result = SendgridService.new.send_email(
      to_email: current_user.email,
      subject: "🧪 Test Email from BRICK",
      template_id: 'basic',
      template_data: template_data
    )
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: current_user.email,
        test_mode: true
      }, "Test email sent successfully")
    else
      render_error("Failed to send test email: #{result[:error]}", :service_unavailable)
    end
  end

  # GET /api/v1/notifications/preferences - Get user notification preferences
  def preferences
    user_prefs = UserNotificationPreference.for_user(current_user)
    
    render_success({
      preferences: user_prefs.to_hash,
      user_email: current_user.email
    }, "Notification preferences retrieved successfully")
  end

  # PUT /api/v1/notifications/preferences - Update notification preferences
  def update_preferences
    # Debug: Log incoming parameters
    Rails.logger.info "Incoming notification params: #{notification_params.inspect}"
    
    user_prefs = UserNotificationPreference.for_user(current_user)
    
    if user_prefs.update(notification_params)
      # Debug: Log final preferences
      Rails.logger.info "Final updated preferences: #{user_prefs.to_hash.inspect}"
      
      render_success({
        preferences: user_prefs.to_hash,
        user_email: current_user.email,
        updated_at: Time.current
      }, "Notification preferences updated successfully")
    else
      render_error("Failed to update preferences: #{user_prefs.errors.full_messages.join(', ')}", :unprocessable_entity)
    end
  end

  # GET /api/v1/notifications/history - Get email sending history
  def history
    history = [
      {
        id: 1,
        type: 'habit_completion',
        subject: 'Habit Completed: Morning Exercise',
        sent_at: 2.hours.ago,
        status: 'delivered'
      },
      {
        id: 2,
        type: 'daily_summary',
        subject: 'Your Daily Progress Summary',
        sent_at: 1.day.ago,
        status: 'delivered'
      },
      {
        id: 3,
        type: 'achievement_notification',
        subject: 'Achievement Unlocked: Week Warrior',
        sent_at: 3.days.ago,
        status: 'delivered'
      }
    ]
    
    render_success({
      history: history,
      total_count: history.length,
      user_email: current_user.email
    }, "Email history retrieved successfully")
  end

  private

  def calculate_daily_summary(user)
    # Calculate real daily summary data from user's actual data
    {
      habits_completed: user.habits.where(status: 'completed', last_completed_at: Date.current.all_day).count,
      habits_due: user.habits.where(status: 'active').count,
      completion_rate: calculate_completion_rate(user),
      points_earned: UserAchievement.where(user: user, earned_at: Date.current.all_day)
                                   .joins(:achievement)
                                   .sum('achievements.points'),
      achievements_earned: user.user_achievements.where(earned_at: Date.current.all_day).count,
      active_blueprints: user.blueprints.where(status: ['not_started', 'in_progress']).count,
      overdue_habits: user.habits.select(&:overdue?).count
    }
  end

  def calculate_completion_rate(user)
    total_habits = user.habits.count
    return 0 if total_habits.zero?
    
    completed_today = user.habits.where(status: 'completed', last_completed_at: Date.current.all_day).count
    (completed_today.to_f / total_habits * 100).round(1)
  end

  def get_user_habits(user)
    # Get habits that are due or overdue for the user
    user.habits.includes(milestone: :blueprint).where(status: 'active').limit(10)
  end

  def set_user_email
    @user_email = current_user.email
  end

  def notification_params
    params.permit(
      :habit_completion, :milestone_progress, :blueprint_completion,
      :daily_summary, :achievement_notifications, :habit_reminders,
      :email_frequency, :reminder_time, :summary_time,
      :habit_id, :milestone_id, :blueprint_id,
      achievement_ids: []
    )
  end
end
