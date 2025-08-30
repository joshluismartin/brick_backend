require 'google/apis/calendar_v3'
require 'googleauth'

class GoogleCalendarService
  include Google::Apis::CalendarV3
  
  def initialize(user)
    @user = user
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = authorize_user
    # Use configured calendar ID or fall back to primary
    @calendar_id = Rails.application.config.google_calendar.target_calendar_id || 'primary'
  end
  
  # Create calendar event for a habit
  def create_habit_event(habit, start_time, end_time = nil)
    return { error: "User not authorized" } unless @service.authorization
    
    end_time ||= start_time + 1.hour
    milestone = habit.milestone
    blueprint = milestone.blueprint
    
    event = Google::Apis::CalendarV3::Event.new(
      summary: "🎯 #{habit.title}",
      description: build_habit_description(habit, milestone, blueprint),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: 'America/New_York'
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: 'America/New_York'
      ),
      color_id: habit_color_by_priority(habit.priority),
      extended_properties: {
        private: {
          'brick_type' => 'habit',
          'habit_id' => habit.id.to_s,
          'milestone_id' => milestone.id.to_s,
          'blueprint_id' => blueprint.id.to_s,
          'frequency' => habit.frequency
        }
      }
    )
    
    begin
      result = @service.insert_event(@calendar_id, event)
      {
        success: true,
        event_id: result.id,
        event_link: result.html_link,
        message: "Calendar event created for habit: #{habit.title}"
      }
    rescue Google::Apis::Error => e
      {
        success: false,
        error: "Failed to create calendar event: #{e.message}"
      }
    end
  end
  
  # Create calendar event for a milestone deadline
  def create_milestone_event(milestone, due_date)
    return { error: "User not authorized" } unless @service.authorization
    
    blueprint = milestone.blueprint
    
    event = Google::Apis::CalendarV3::Event.new(
      summary: "📋 Milestone Due: #{milestone.title}",
      description: build_milestone_description(milestone, blueprint),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date: due_date.to_date.iso8601,
        time_zone: 'America/New_York'
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date: due_date.to_date.iso8601,
        time_zone: 'America/New_York'
      ),
      color_id: milestone_color_by_priority(milestone.priority),
      extended_properties: {
        private: {
          'brick_type' => 'milestone',
          'milestone_id' => milestone.id.to_s,
          'blueprint_id' => blueprint.id.to_s
        }
      }
    )
    
    begin
      result = @service.insert_event(@calendar_id, event)
      {
        success: true,
        event_id: result.id,
        event_link: result.html_link,
        message: "Calendar event created for milestone: #{milestone.title}"
      }
    rescue Google::Apis::Error => e
      {
        success: false,
        error: "Failed to create calendar event: #{e.message}"
      }
    end
  end
  
  # Create recurring events for daily/weekly/monthly habits
  def create_recurring_habit_events(habit, start_date, end_date, time_of_day = "09:00")
    return { error: "User not authorized" } unless @service.authorization
    
    recurrence_rule = build_recurrence_rule(habit.frequency, end_date)
    start_datetime = DateTime.parse("#{start_date.to_date} #{time_of_day}")
    end_datetime = start_datetime + 1.hour
    
    milestone = habit.milestone
    blueprint = milestone.blueprint
    
    event = Google::Apis::CalendarV3::Event.new(
      summary: "🔄 #{habit.title} (#{habit.frequency.capitalize})",
      description: build_habit_description(habit, milestone, blueprint),
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_datetime.iso8601,
        time_zone: 'America/New_York'
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_datetime.iso8601,
        time_zone: 'America/New_York'
      ),
      recurrence: [recurrence_rule],
      color_id: habit_color_by_priority(habit.priority),
      extended_properties: {
        private: {
          'brick_type' => 'recurring_habit',
          'habit_id' => habit.id.to_s,
          'milestone_id' => milestone.id.to_s,
          'blueprint_id' => blueprint.id.to_s,
          'frequency' => habit.frequency
        }
      }
    )
    
    begin
      result = @service.insert_event(@calendar_id, event)
      {
        success: true,
        event_id: result.id,
        event_link: result.html_link,
        message: "Recurring calendar events created for habit: #{habit.title}"
      }
    rescue Google::Apis::Error => e
      {
        success: false,
        error: "Failed to create recurring events: #{e.message}"
      }
    end
  end
  
  # Get upcoming BRICK-related events
  def get_brick_events(days_ahead = 7)
    return { error: "User not authorized" } unless @service.authorization
    
    time_min = Time.current.iso8601
    time_max = (Time.current + days_ahead.days).iso8601
    
    begin
      result = @service.list_events(@calendar_id,
        time_min: time_min,
        time_max: time_max,
        single_events: true,
        order_by: 'startTime'
      )
      
      brick_events = result.items.select do |event|
        event.extended_properties&.private&.has_key?('brick_type')
      end
      
      {
        success: true,
        events: brick_events.map { |event| format_event_response(event) }
      }
    rescue Google::Apis::Error => e
      {
        success: false,
        error: "Failed to fetch events: #{e.message}"
      }
    end
  end
  
  # Update calendar event
  def update_event(event_id, updates = {})
    return { error: "User not authorized" } unless @service.authorization
    
    begin
      event = @service.get_event(@calendar_id, event_id)
      
      # Apply updates
      event.summary = updates[:summary] if updates[:summary]
      event.description = updates[:description] if updates[:description]
      
      if updates[:start_time]
        event.start.date_time = updates[:start_time].iso8601
        event.end.date_time = (updates[:end_time] || updates[:start_time] + 1.hour).iso8601
      end
      
      result = @service.update_event(@calendar_id, event_id, event)
      {
        success: true,
        message: "Calendar event updated successfully"
      }
    rescue Google::Apis::Error => e
      {
        success: false,
        error: "Failed to update event: #{e.message}"
      }
    end
  end
  
  # Delete calendar event
  def delete_event(event_id)
    return { error: "User not authorized" } unless @service.authorization
    
    begin
      @service.delete_event(@calendar_id, event_id)
      {
        success: true,
        message: "Calendar event deleted successfully"
      }
    rescue Google::Apis::Error => e
      {
        success: false,
        error: "Failed to delete event: #{e.message}"
      }
    end
  end
  
  private
  
  def authorize_user
    # Service Account authentication for server-to-server communication
    begin
      credentials_path = Rails.application.config.google_calendar.credentials_path
      
      if File.exist?(credentials_path)
        # Use service account credentials from JSON file
        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(credentials_path),
          scope: Rails.application.config.google_calendar.scopes
        )
      else
        # Fallback to application default credentials (for production)
        Google::Auth.get_application_default(Rails.application.config.google_calendar.scopes)
      end
    rescue => e
      Rails.logger.error "Google Calendar authorization failed: #{e.message}"
      Rails.logger.error "Make sure GOOGLE_APPLICATION_CREDENTIALS is set and points to valid service account JSON"
      nil
    end
  end
  
  def build_habit_description(habit, milestone, blueprint)
    description = "🎯 BRICK Habit Tracking\n\n"
    description += "Habit: #{habit.title}\n"
    description += "Description: #{habit.description}\n" if habit.description.present?
    description += "Frequency: #{habit.frequency.capitalize}\n"
    description += "Priority: #{habit.priority.capitalize}\n\n"
    description += "📋 Milestone: #{milestone.title}\n"
    description += "🏗️ Blueprint: #{blueprint.title}\n\n"
    description += "Status: #{habit.status.humanize}\n"
    description += "Progress: #{habit.progress_percentage.round(1)}%\n\n"
    description += "💡 Tip: Mark this habit as completed in your BRICK app to track your progress!"
    description
  end
  
  def build_milestone_description(milestone, blueprint)
    description = "📋 BRICK Milestone Deadline\n\n"
    description += "Milestone: #{milestone.title}\n"
    description += "Description: #{milestone.description}\n" if milestone.description.present?
    description += "Priority: #{milestone.priority.capitalize}\n\n"
    description += "🏗️ Blueprint: #{blueprint.title}\n\n"
    description += "Status: #{milestone.status.humanize}\n"
    description += "Progress: #{milestone.progress_percentage.round(1)}%\n\n"
    description += "📊 Habits in this milestone: #{milestone.habits.count}\n"
    description += "✅ Completed habits: #{milestone.habits.completed.count}\n\n"
    description += "🎯 Complete all habits to achieve this milestone!"
    description
  end
  
  def build_recurrence_rule(frequency, end_date)
    case frequency
    when 'daily'
      "RRULE:FREQ=DAILY;UNTIL=#{end_date.strftime('%Y%m%dT235959Z')}"
    when 'weekly'
      "RRULE:FREQ=WEEKLY;UNTIL=#{end_date.strftime('%Y%m%dT235959Z')}"
    when 'monthly'
      "RRULE:FREQ=MONTHLY;UNTIL=#{end_date.strftime('%Y%m%dT235959Z')}"
    else
      "RRULE:FREQ=DAILY;COUNT=1" # Single occurrence
    end
  end
  
  def habit_color_by_priority(priority)
    case priority
    when 'high'
      '11' # Red
    when 'medium'
      '5'  # Yellow
    when 'low'
      '10' # Green
    else
      '1'  # Blue (default)
    end
  end
  
  def milestone_color_by_priority(priority)
    case priority
    when 'high'
      '4'  # Flamingo (pink-red)
    when 'medium'
      '6'  # Orange
    when 'low'
      '2'  # Sage (light green)
    else
      '9'  # Blueberry (default)
    end
  end
  
  def format_event_response(event)
    {
      id: event.id,
      title: event.summary,
      description: event.description,
      start_time: event.start.date_time || event.start.date,
      end_time: event.end.date_time || event.end.date,
      html_link: event.html_link,
      brick_type: event.extended_properties&.private&.[]('brick_type'),
      habit_id: event.extended_properties&.private&.[]('habit_id'),
      milestone_id: event.extended_properties&.private&.[]('milestone_id'),
      blueprint_id: event.extended_properties&.private&.[]('blueprint_id')
    }
  end
end
