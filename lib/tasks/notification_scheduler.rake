namespace :notifications do
  desc "Send habit reminders to users based on their preferences"
  task send_habit_reminders: :environment do
    puts "Starting habit reminder job at #{Time.current}"
    
    # Get users who have habit reminders enabled
    users_with_reminders = User.joins(:user_notification_preference)
                              .where(user_notification_preferences: { habit_reminders: true })
    
    users_with_reminders.find_each do |user|
      prefs = user.user_notification_preference
      current_time = Time.current.strftime("%H:%M")
      
      puts "User: #{user.email}, Reminder time: #{prefs.reminder_time}, Current time: #{current_time}"
      
      # Check if it's time to send reminders for this user OR if debug mode
      if current_time == prefs.reminder_time || ENV['DEBUG_NOTIFICATIONS'] == 'true'
        habits = user.habits.includes(milestone: :blueprint).where(status: 'active').limit(10)
        
        puts "Found #{habits.count} active habits for #{user.email}"
        
        if habits.any?
          result = SendgridService.send_habit_reminder(user.email, habits)
          
          if result && result[:success]
            puts "✅ Sent habit reminder to #{user.email}"
          else
            puts "❌ Failed to send habit reminder to #{user.email}: #{result&.dig(:error) || 'No result returned'}"
          end
        else
          puts "⚠️  No active habits found for #{user.email}"
        end
      else
        puts "⏰ Not time yet for #{user.email} (#{prefs.reminder_time} vs #{current_time})"
      end
    end
    
    puts "Completed habit reminder job at #{Time.current}"
  end

  desc "Send daily summaries to users based on their preferences"
  task send_daily_summaries: :environment do
    puts "Starting daily summary job at #{Time.current}"
    
    # Get users who have daily summaries enabled
    users_with_summaries = User.joins(:user_notification_preference)
                              .where(user_notification_preferences: { daily_summary: true })
    
    users_with_summaries.find_each do |user|
      prefs = user.user_notification_preference
      current_time = Time.current.strftime("%H:%M")
      
      puts "User: #{user.email}, Summary time: #{prefs.summary_time}, Current time: #{current_time}"
      
      # Check if it's time to send summary for this user OR if debug mode
      if current_time == prefs.summary_time || ENV['DEBUG_NOTIFICATIONS'] == 'true'
        # Calculate daily summary data for the user
        summary_data = calculate_daily_summary_for_user(user)
        
        result = SendgridService.send_daily_summary_email(user.email, summary_data)
        
        if result && result[:success]
          puts "✅ Sent daily summary to #{user.email}"
        else
          puts "❌ Failed to send daily summary to #{user.email}: #{result&.dig(:error) || 'No result returned'}"
        end
      else
        puts "⏰ Not time yet for #{user.email} (#{prefs.summary_time} vs #{current_time})"
      end
    end
    
    puts "Completed daily summary job at #{Time.current}"
  end

  private

  def calculate_daily_summary_for_user(user)
    {
      habits_completed: user.habits.where(status: 'completed', last_completed_at: Date.current.all_day).count,
      habits_due: user.habits.where(status: 'active').count,
      completion_rate: calculate_completion_rate_for_user(user),
      points_earned: UserAchievement.where(user: user, earned_at: Date.current.all_day)
                                   .joins(:achievement)
                                   .sum('achievements.points'),
      achievements_earned: user.user_achievements.where(earned_at: Date.current.all_day).count,
      active_blueprints: user.blueprints.where(status: ['not_started', 'in_progress']).count,
      overdue_habits: user.habits.select(&:overdue?).count
    }
  end

  def calculate_completion_rate_for_user(user)
    total_habits = user.habits.count
    return 0 if total_habits.zero?
    
    completed_today = user.habits.where(status: 'completed', last_completed_at: Date.current.all_day).count
    (completed_today.to_f / total_habits * 100).round(1)
  end
end
