class Api::V1::NotificationsController < Api::V1::BaseController
  before_action :set_user_email
  
  # POST /api/v1/notifications/habit_completion - Send habit completion email
  def habit_completion
    habit = Habit.find(params[:habit_id])
    achievements = params[:achievements] || []
    
    # Convert achievement IDs to objects if provided
    achievement_objects = if achievements.any?
      UserAchievement.includes(:achievement).where(id: achievements)
    else
      []
    end
    
    result = SendgridService.send_habit_completion_email(@user_email, habit, achievement_objects)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: @user_email,
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
    milestone = Milestone.find(params[:milestone_id])
    
    result = SendgridService.send_milestone_progress_email(@user_email, milestone)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: @user_email,
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
    blueprint = Blueprint.find(params[:blueprint_id])
    
    result = SendgridService.send_blueprint_completion_email(@user_email, blueprint)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: @user_email,
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
    user_identifier = params[:user_identifier] || 'demo_user'
    
    # Calculate daily summary data
    summary_data = calculate_daily_summary(user_identifier)
    
    result = SendgridService.send_daily_summary_email(@user_email, summary_data)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: @user_email,
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
    
    achievements = UserAchievement.includes(:achievement).where(id: achievement_ids)
    
    if achievements.empty?
      render_error("No valid achievements found", :not_found)
      return
    end
    
    result = SendgridService.send_achievement_notification(@user_email, achievements)
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: @user_email,
        achievements_count: achievements.length,
        total_points: achievements.sum { |a| a.achievement.points }
      }, "Achievement notification email sent successfully")
    else
      render_error("Failed to send email: #{result[:error]}", :service_unavailable)
    end
  end

  # POST /api/v1/notifications/habit_reminder - Send habit reminder email
  def habit_reminder
    user_identifier = params[:user_identifier] || 'demo_user'
    
    # Get habits due today and overdue habits
    # For demo purposes, we'll use all active habits
    habits = get_user_habits(user_identifier)
    
    if habits.empty?
      render_error("No habits found for reminders", :not_found)
      return
    end
    
    result = SendgridService.send_habit_reminder(@user_email, habits)
    
    if result[:success]
      overdue_count = habits.count(&:overdue?)
      due_today_count = habits.count - overdue_count
      
      render_success({
        email_sent: true,
        recipient: @user_email,
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
      user_email: @user_email
    }
    
    result = SendgridService.new.send_email(
      to_email: @user_email,
      subject: "🧪 Test Email from BRICK",
      template_id: 'basic',
      template_data: template_data
    )
    
    if result[:success]
      render_success({
        email_sent: true,
        recipient: @user_email,
        test_mode: true
      }, "Test email sent successfully")
    else
      render_error("Failed to send test email: #{result[:error]}", :service_unavailable)
    end
  end

  # GET /api/v1/notifications/preferences - Get user notification preferences
  def preferences
    # For now, return default preferences
    # In the future, this would be stored per user
    preferences = {
      habit_completion: true,
      milestone_progress: true,
      blueprint_completion: true,
      daily_summary: true,
      achievement_notifications: true,
      habit_reminders: true,
      email_frequency: 'immediate', # immediate, daily, weekly
      reminder_time: '09:00',
      summary_time: '18:00'
    }
    
    render_success({
      preferences: preferences,
      user_email: @user_email
    }, "Notification preferences retrieved successfully")
  end

  # PUT /api/v1/notifications/preferences - Update notification preferences
  def update_preferences
    # For now, just return the updated preferences
    # In the future, this would be stored in the database
    updated_preferences = notification_params
    
    render_success({
      preferences: updated_preferences,
      user_email: @user_email,
      updated_at: Time.current
    }, "Notification preferences updated successfully")
  end

  # GET /api/v1/notifications/history - Get email sending history
  def history
    # For now, return mock history
    # In production, you'd track email sends in the database
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
      user_email: @user_email
    }, "Email history retrieved successfully")
  end

  private

  def set_user_email
    # For now, use email from params or headers
    # In the future, this will come from authenticated user
    @user_email = params[:user_email] || 
                  request.headers['X-User-Email'] || 
                  'demo@brickgoals.com'
    
    # Basic email validation
    unless @user_email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      render_error("Invalid email address", :bad_request)
      return
    end
  end

  def calculate_daily_summary(user_identifier)
    # Mock daily summary calculation
    # In a real app, you'd calculate this from actual user data
    {
      habits_completed: rand(0..5),
      habits_due: rand(3..8),
      completion_rate: rand(60..100),
      points_earned: rand(10..50),
      achievements_earned: [],
      active_blueprints: rand(1..3),
      overdue_habits: rand(0..2)
    }
  end

  def get_user_habits(user_identifier)
    # For demo purposes, get some sample habits
    # In a real app, you'd filter by user
    Habit.includes(milestone: :blueprint).limit(5)
  end

  def notification_params
    params.permit(
      :habit_completion, :milestone_progress, :blueprint_completion,
      :daily_summary, :achievement_notifications, :habit_reminders,
      :email_frequency, :reminder_time, :summary_time, :user_email,
      :habit_id, :milestone_id, :blueprint_id, :user_identifier,
      achievement_ids: []
    )
  end
end
