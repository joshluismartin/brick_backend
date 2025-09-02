require 'sendgrid-ruby'

class SendgridService
  include SendGrid
  
  def initialize
    @sg = SendGrid::API.new(api_key: Rails.application.credentials.sendgrid&.api_key || ENV['SENDGRID_API_KEY'])
  end
  
  # Send habit completion celebration email
  def self.send_habit_completion_email(user_email, habit, achievements = [])
    new.send_habit_completion_email(user_email, habit, achievements)
  end
  
  # Send milestone progress notification
  def self.send_milestone_progress_email(user_email, milestone)
    new.send_milestone_progress_email(user_email, milestone)
  end
  
  # Send blueprint completion celebration
  def self.send_blueprint_completion_email(user_email, blueprint)
    new.send_blueprint_completion_email(user_email, blueprint)
  end
  
  # Send daily progress summary
  def self.send_daily_summary_email(user_email, summary_data)
    new.send_daily_summary_email(user_email, summary_data)
  end
  
  # Send achievement notification
  def self.send_achievement_notification(user_email, achievements)
    new.send_achievement_notification(user_email, achievements)
  end
  
  # Send habit reminder
  def self.send_habit_reminder(user_email, habits)
    new.send_habit_reminder(user_email, habits)
  end
  
  def send_habit_completion_email(user_email, habit, achievements = [])
    milestone = habit.milestone
    blueprint = milestone.blueprint
    
    template_data = {
      habit_title: habit.title,
      milestone_title: milestone.title,
      blueprint_title: blueprint.title,
      completion_time: Time.current.strftime("%B %d, %Y at %I:%M %p"),
      achievements: achievements.map(&:display_info),
      total_points: achievements.sum { |a| a.achievement.points },
      progress_percentage: milestone.progress_percentage.round(1)
    }
    
    send_email(
      to_email: user_email,
      subject: "🎉 Habit Completed: #{habit.title}",
      template_id: 'habit_completion',
      template_data: template_data
    )
  end
  
  def send_milestone_progress_email(user_email, milestone)
    blueprint = milestone.blueprint
    progress = milestone.progress_percentage
    
    template_data = {
      milestone_title: milestone.title,
      blueprint_title: blueprint.title,
      progress_percentage: progress.round(1),
      completed_habits: milestone.habits.where(status: 'completed').count,
      total_habits: milestone.habits.count,
      days_remaining: milestone.days_remaining,
      target_date: milestone.target_date.strftime("%B %d, %Y")
    }
    
    subject = if progress >= 90
      "🎯 Almost There! #{milestone.title} is #{progress.round}% Complete"
    elsif progress >= 50
      "📈 Great Progress! #{milestone.title} is #{progress.round}% Complete"
    else
      "🚀 Keep Going! #{milestone.title} Progress Update"
    end
    
    send_email(
      to_email: user_email,
      subject: subject,
      template_id: 'milestone_progress',
      template_data: template_data
    )
  end
  
  def send_blueprint_completion_email(user_email, blueprint)
    completion_time = Time.current
    was_early = blueprint.target_date > Date.current
    
    template_data = {
      blueprint_title: blueprint.title,
      completion_date: completion_time.strftime("%B %d, %Y"),
      target_date: blueprint.target_date.strftime("%B %d, %Y"),
      was_early: was_early,
      days_difference: was_early ? (blueprint.target_date - Date.current).to_i : 0,
      total_milestones: blueprint.milestones.count,
      total_habits: blueprint.milestones.joins(:habits).count,
      category: blueprint.category&.titleize || 'Personal'
    }
    
    subject = if was_early
      "🚀 Amazing! You completed '#{blueprint.title}' early!"
    else
      "🏆 Congratulations! You completed '#{blueprint.title}'!"
    end
    
    send_email(
      to_email: user_email,
      subject: subject,
      template_id: 'blueprint_completion',
      template_data: template_data
    )
  end
  
  def send_daily_summary_email(user_email, summary_data)
    template_data = {
      date: Date.current.strftime("%B %d, %Y"),
      habits_completed: summary_data[:habits_completed] || 0,
      habits_due: summary_data[:habits_due] || 0,
      completion_rate: summary_data[:completion_rate] || 0,
      points_earned: summary_data[:points_earned] || 0,
      achievements_earned: summary_data[:achievements_earned] || [],
      active_blueprints: summary_data[:active_blueprints] || 0,
      overdue_habits: summary_data[:overdue_habits] || 0,
      motivational_quote: "Believe you can and you're halfway there." # default quote
    }
    
    send_email(
      to_email: user_email,
      subject: "📊 Your Daily Progress Summary - #{Date.current.strftime('%B %d')}",
      template_id: 'daily_summary',
      template_data: template_data
    )
  end
  
  def send_achievement_notification(user_email, achievements)
    return if achievements.empty?
    
    total_points = achievements.sum(&:points)
    rarest_achievement = achievements.max_by(&:difficulty_level)
    
    template_data = {
      achievements: achievements.map { |a| { name: a.name, description: a.description, points: a.points } },
      achievement_count: achievements.length,
      total_points: total_points,
      rarest_achievement: rarest_achievement&.name,
      celebration_message: "Congratulations on your achievements!"
    }
    
    subject = if achievements.length > 1
      "🏆 #{achievements.length} New Achievements Unlocked!"
    else
      "🎖️ Achievement Unlocked: #{achievements.first.name}"
    end
    
    send_email(
      to_email: user_email,
      subject: subject,
      template_id: 'achievement_notification',
      template_data: template_data
    )
  end
  
  def send_habit_reminder(user_email, habits)
    return if habits.empty?
    
    overdue_habits = habits.select(&:overdue?)
    due_today = habits.reject(&:overdue?)
    
    template_data = {
      habits_due_today: due_today.map { |h| {
        title: h.title,
        milestone: h.milestone.title,
        blueprint: h.milestone.blueprint.title,
        frequency: h.frequency
      }},
      overdue_habits: overdue_habits.map { |h| {
        title: h.title,
        days_overdue: (Date.current - h.next_due_date).to_i,
        milestone: h.milestone.title
      }},
      total_habits: habits.length,
      motivational_quote: "Believe you can and you're halfway there." # default quote
    }
    
    subject = if overdue_habits.any?
      "⏰ Habit Reminder: #{overdue_habits.length} overdue, #{due_today.length} due today"
    else
      "📅 Daily Habit Reminder: #{habits.length} habits due today"
    end
    
    send_email(
      to_email: user_email,
      subject: subject,
      template_id: 'habit_reminder',
      template_data: template_data
    )
  end
  
  def send_email(to_email:, subject:, template_id:, template_data: {})
    from_email = ENV['SENDGRID_FROM_EMAIL'] || 'noreply@brickgoals.com'
    from_name = ENV['SENDGRID_FROM_NAME'] || 'BRICK Goal Achievement'
    
    from = Email.new(email: from_email, name: from_name)
    to = Email.new(email: to_email)
    
    # For now, send simple HTML email
    # In production, you'd use SendGrid templates
    html_content = generate_html_content(template_id, template_data)
    
    content = Content.new(type: 'text/html', value: html_content)
    mail = Mail.new(from, subject, to, content)
    
    begin
      response = @sg.client.mail._('send').post(request_body: mail.to_json)
      
      if response.status_code.to_i >= 200 && response.status_code.to_i < 300
        Rails.logger.info "Email sent successfully to #{to_email}: #{subject}"
        { success: true, message: 'Email sent successfully' }
      else
        Rails.logger.error "SendGrid error: #{response.status_code} - #{response.body}"
        { success: false, error: "SendGrid error: #{response.status_code}" }
      end
    rescue => e
      Rails.logger.error "Email sending failed: #{e.message}"
      { success: false, error: e.message }
    end
  end
  
  private
  
  def generate_html_content(template_id, data)
    case template_id
    when 'habit_completion'
      habit_completion_template(data)
    when 'milestone_progress'
      milestone_progress_template(data)
    when 'blueprint_completion'
      blueprint_completion_template(data)
    when 'daily_summary'
      daily_summary_template(data)
    when 'achievement_notification'
      achievement_notification_template(data)
    when 'habit_reminder'
      habit_reminder_template(data)
    else
      basic_template(data)
    end
  end
  
  def habit_completion_template(data)
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #4CAF50;">🎉 Habit Completed!</h1>
        <p>Congratulations! You've successfully completed your habit:</p>
        
        <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #333; margin: 0;">#{data[:habit_title]}</h3>
          <p style="color: #666; margin: 5px 0;">Part of: #{data[:milestone_title]}</p>
          <p style="color: #666; margin: 5px 0;">Blueprint: #{data[:blueprint_title]}</p>
          <p style="color: #666; margin: 5px 0;">Completed: #{data[:completion_time]}</p>
        </div>
        
        #{achievement_section(data[:achievements]) if data[:achievements].any?}
        
        <div style="background: #e3f2fd; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <h4 style="color: #1976d2; margin: 0 0 10px 0;">💬 Motivational Quote</h4>
          <blockquote style="font-style: italic; margin: 0; color: #555;">
            "Believe you can and you're halfway there."
          </blockquote>
          <p style="text-align: right; color: #777; margin: 10px 0 0 0;">— Theodore Roosevelt</p>
        </div>
        
        <div style="background: #fff3e0; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <h4 style="color: #f57c00; margin: 0 0 10px 0;">📊 Progress Update</h4>
          <p>Milestone "#{data[:milestone_title]}" is now <strong>#{data[:progress_percentage]}%</strong> complete!</p>
        </div>
        
        <p style="color: #666;">Keep up the great work! Every habit completed brings you closer to achieving your goals.</p>
      </div>
    HTML
  end
  
  def achievement_section(achievements)
    return '' if achievements.empty?
    
    achievement_items = achievements.map do |achievement|
      "<li style='margin: 5px 0;'>#{achievement[:icon]} <strong>#{achievement[:name]}</strong> - #{achievement[:points]} points</li>"
    end.join
    
    <<~HTML
      <div style="background: #fff8e1; padding: 15px; border-radius: 8px; margin: 20px 0;">
        <h4 style="color: #f9a825; margin: 0 0 10px 0;">🏆 New Achievements!</h4>
        <ul style="margin: 0; padding-left: 20px;">
          #{achievement_items}
        </ul>
      </div>
    HTML
  end
  
  def milestone_progress_template(data)
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #2196F3;">📈 Milestone Progress Update</h1>
        
        <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #333; margin: 0;">#{data[:milestone_title]}</h3>
          <p style="color: #666; margin: 5px 0;">Blueprint: #{data[:blueprint_title]}</p>
          
          <div style="background: #fff; padding: 10px; border-radius: 4px; margin: 10px 0;">
            <div style="background: #e0e0e0; height: 20px; border-radius: 10px; overflow: hidden;">
              <div style="background: #4CAF50; height: 100%; width: #{data[:progress_percentage]}%; transition: width 0.3s;"></div>
            </div>
            <p style="text-align: center; margin: 5px 0; font-weight: bold;">#{data[:progress_percentage]}% Complete</p>
          </div>
          
          <p>✅ #{data[:completed_habits]} of #{data[:total_habits]} habits completed</p>
          <p>📅 #{data[:days_remaining]} days remaining until #{data[:target_date]}</p>
        </div>
        
        <p style="color: #666;">You're making excellent progress! Keep up the momentum.</p>
      </div>
    HTML
  end
  
  def blueprint_completion_template(data)
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #4CAF50;">🏆 Blueprint Completed!</h1>
        
        <div style="background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
          <h2 style="margin: 0 0 10px 0;">#{data[:blueprint_title]}</h2>
          <p style="margin: 0;">#{data[:category]} Goal</p>
          #{data[:was_early] ? "<p style='margin: 10px 0 0 0; font-weight: bold;'>🚀 Completed #{data[:days_difference]} days early!</p>" : ""}
        </div>
        
        <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <h4 style="color: #333; margin: 0 0 10px 0;">📊 Achievement Summary</h4>
          <p>✅ Completed #{data[:total_milestones]} milestones</p>
          <p>🎯 Finished #{data[:total_habits]} habits</p>
          <p>📅 Completion Date: #{data[:completion_date]}</p>
          <p>🎯 Target Date: #{data[:target_date]}</p>
        </div>
        
        <p style="color: #666;">Congratulations on this incredible achievement! You've proven that with dedication and consistency, any goal is achievable.</p>
      </div>
    HTML
  end
  
  def daily_summary_template(data)
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #FF9800;">📊 Daily Progress Summary</h1>
        <p style="color: #666;">#{data[:date]}</p>
        
        <div style="display: flex; gap: 10px; margin: 20px 0;">
          <div style="flex: 1; background: #e8f5e8; padding: 15px; border-radius: 8px; text-align: center;">
            <h3 style="color: #4CAF50; margin: 0;">#{data[:habits_completed]}</h3>
            <p style="margin: 5px 0 0 0; color: #666;">Habits Completed</p>
          </div>
          <div style="flex: 1; background: #fff3e0; padding: 15px; border-radius: 8px; text-align: center;">
            <h3 style="color: #FF9800; margin: 0;">#{data[:points_earned]}</h3>
            <p style="margin: 5px 0 0 0; color: #666;">Points Earned</p>
          </div>
        </div>
        
        #{data[:overdue_habits] > 0 ? "<div style='background: #ffebee; padding: 15px; border-radius: 8px; margin: 20px 0;'><p style='color: #d32f2f; margin: 0;'>⚠️ #{data[:overdue_habits]} habits are overdue</p></div>" : ""}
        
        <p style="color: #666;">Keep building those positive habits! Tomorrow is another opportunity to make progress.</p>
      </div>
    HTML
  end
  
  def achievement_notification_template(data)
    achievement_items = data[:achievements].map do |achievement|
      "<div style='background: #{achievement[:color]}20; padding: 10px; border-radius: 4px; margin: 5px 0;'>#{achievement[:icon]} <strong>#{achievement[:name]}</strong> - #{achievement[:points]} points</div>"
    end.join
    
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #FFD700;">🏆 New Achievements Unlocked!</h1>
        
        <div style="margin: 20px 0;">
          #{achievement_items}
        </div>
        
        <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: center;">
          <h3 style="color: #333; margin: 0;">Total Points Earned: #{data[:total_points]}</h3>
        </div>
        
        <p style="color: #666;">#{data[:celebration_message]}</p>
      </div>
    HTML
  end
  
  def habit_reminder_template(data)
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #2196F3;">📅 Daily Habit Reminder</h1>
        
        #{data[:overdue_habits].any? ? overdue_section(data[:overdue_habits]) : ""}
        #{data[:habits_due_today].any? ? due_today_section(data[:habits_due_today]) : ""}
        
        <div style="background: #e3f2fd; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <h4 style="color: #1976d2; margin: 0 0 10px 0;">💬 Daily Motivation</h4>
          <blockquote style="font-style: italic; margin: 0; color: #555;">
            "Believe you can and you're halfway there."
          </blockquote>
          <p style="text-align: right; color: #777; margin: 10px 0 0 0;">— Theodore Roosevelt</p>
        </div>
        
        <p style="color: #666;">Make today count! Every habit completed is a step toward your goals.</p>
      </div>
    HTML
  end
  
  def overdue_section(overdue_habits)
    items = overdue_habits.map do |habit|
      "<li>#{habit[:title]} (#{habit[:days_overdue]} days overdue)</li>"
    end.join
    
    <<~HTML
      <div style="background: #ffebee; padding: 15px; border-radius: 8px; margin: 20px 0;">
        <h4 style="color: #d32f2f; margin: 0 0 10px 0;">⚠️ Overdue Habits</h4>
        <ul style="margin: 0; padding-left: 20px;">#{items}</ul>
      </div>
    HTML
  end
  
  def due_today_section(habits_due)
    items = habits_due.map do |habit|
      "<li>#{habit[:title]} (#{habit[:frequency]})</li>"
    end.join
    
    <<~HTML
      <div style="background: #e8f5e8; padding: 15px; border-radius: 8px; margin: 20px 0;">
        <h4 style="color: #4CAF50; margin: 0 0 10px 0;">📋 Due Today</h4>
        <ul style="margin: 0; padding-left: 20px;">#{items}</ul>
      </div>
    HTML
  end
  
  def basic_template(data)
    <<~HTML
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1>BRICK Goal Achievement</h1>
        <p>#{data[:message] || 'Thank you for using BRICK!'}</p>
      </div>
    HTML
  end
end
