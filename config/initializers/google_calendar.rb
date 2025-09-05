require 'google/apis/calendar_v3'
require 'googleauth'

# Google Calendar API Configuration
Rails.application.configure do
  # Google Calendar API settings
  config.google_calendar = ActiveSupport::OrderedOptions.new
  
  # API Configuration
  config.google_calendar.application_name = ENV['GOOGLE_APPLICATION_NAME'] || 'BRICK Goal Tracker'
  config.google_calendar.application_version = ENV['GOOGLE_APPLICATION_VERSION'] || '1.0.0'
  
  # Authentication scopes
  config.google_calendar.scopes = [
    Google::Apis::CalendarV3::AUTH_CALENDAR,
    Google::Apis::CalendarV3::AUTH_CALENDAR_EVENTS
  ]
  
  # Credentials configuration
  config.google_calendar.credentials_path = ENV['GOOGLE_APPLICATION_CREDENTIALS'] || 
    Rails.root.join('config', 'google_credentials.json')
  
  # Service account email (if using service account)
  config.google_calendar.service_account_email = ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL']
  
  # OAuth2 configuration (for user authentication)
  config.google_calendar.oauth2 = ActiveSupport::OrderedOptions.new
  config.google_calendar.oauth2.client_id = ENV['GOOGLE_OAUTH_CLIENT_ID']
  config.google_calendar.oauth2.client_secret = ENV['GOOGLE_OAUTH_CLIENT_SECRET']
  config.google_calendar.oauth2.redirect_uri = ENV['GOOGLE_OAUTH_REDIRECT_URI'] || 
    "#{ENV['APP_BASE_URL'] || 'http://localhost:3000'}/api/v1/auth/google/callback"
  
  # Calendar settings
  config.google_calendar.default_timezone = ENV['DEFAULT_TIMEZONE'] || 'America/New_York'
  config.google_calendar.default_calendar_id = 'primary'
  config.google_calendar.target_calendar_id = ENV['GOOGLE_TARGET_CALENDAR_ID'] # Set this to your email or calendar ID
  
  # Event defaults
  config.google_calendar.defaults = ActiveSupport::OrderedOptions.new
  config.google_calendar.defaults.event_duration = 1.hour
  config.google_calendar.defaults.reminder_minutes = [15, 60] # 15 min popup, 1 hour email
  config.google_calendar.defaults.habit_time = '09:00'
  config.google_calendar.defaults.recurring_period_days = 30
  
  # Color mapping for different priorities and types
  config.google_calendar.colors = ActiveSupport::OrderedOptions.new
  config.google_calendar.colors.habit = ActiveSupport::OrderedOptions.new
  config.google_calendar.colors.habit.high = '11'    # Red
  config.google_calendar.colors.habit.medium = '5'   # Yellow
  config.google_calendar.colors.habit.low = '10'     # Green
  config.google_calendar.colors.habit.default = '1'  # Blue
  
  config.google_calendar.colors.milestone = ActiveSupport::OrderedOptions.new
  config.google_calendar.colors.milestone.high = '4'    # Flamingo
  config.google_calendar.colors.milestone.medium = '6'  # Orange
  config.google_calendar.colors.milestone.low = '2'     # Sage
  config.google_calendar.colors.milestone.default = '9' # Blueberry
  
  # Rate limiting and retry configuration
  config.google_calendar.rate_limit = ActiveSupport::OrderedOptions.new
  config.google_calendar.rate_limit.requests_per_second = 10
  config.google_calendar.rate_limit.max_retries = 3
  config.google_calendar.rate_limit.retry_delay = 1.second
  
  # Feature flags
  config.google_calendar.features = ActiveSupport::OrderedOptions.new
  config.google_calendar.features.auto_sync_enabled = ENV['GOOGLE_CALENDAR_AUTO_SYNC'] == 'true'
  config.google_calendar.features.webhook_notifications = ENV['GOOGLE_CALENDAR_WEBHOOKS'] == 'true'
  config.google_calendar.features.batch_operations = ENV['GOOGLE_CALENDAR_BATCH_OPS'] == 'true'
  
  # Logging configuration
  config.google_calendar.logging = ActiveSupport::OrderedOptions.new
  config.google_calendar.logging.enabled = Rails.env.development? || ENV['GOOGLE_CALENDAR_LOGGING'] == 'true'
  config.google_calendar.logging.level = ENV['GOOGLE_CALENDAR_LOG_LEVEL'] || 'info'
end

# Initialize Google Calendar API client with global configuration
Google::Apis::CalendarV3::CalendarService.class_eval do
  def self.configure_defaults(service)
    service.client_options.application_name = Rails.application.config.google_calendar.application_name
    service.client_options.application_version = Rails.application.config.google_calendar.application_version
    service.request_options.retries = Rails.application.config.google_calendar.rate_limit.max_retries
    service
  end
end

# Custom error classes for better error handling
module GoogleCalendarErrors
  class AuthenticationError < StandardError; end
  class QuotaExceededError < StandardError; end
  class CalendarNotFoundError < StandardError; end
  class EventNotFoundError < StandardError; end
  class InvalidDateTimeError < StandardError; end
end

# Utility methods for Google Calendar integration
module GoogleCalendarHelpers
  extend self
  
  def format_datetime(datetime, timezone = nil)
    timezone ||= Rails.application.config.google_calendar.default_timezone
    datetime.in_time_zone(timezone).iso8601
  end
  
  def format_date(date)
    date.to_date.iso8601
  end
  
  def parse_google_datetime(google_datetime)
    if google_datetime.date_time
      DateTime.parse(google_datetime.date_time)
    elsif google_datetime.date
      Date.parse(google_datetime.date)
    else
      nil
    end
  end
  
  def color_for_priority(type, priority)
    colors = Rails.application.config.google_calendar.colors
    type_colors = colors.send(type.to_sym)
    type_colors.send(priority.to_sym) || type_colors.default
  rescue
    '1' # Default blue color
  end
  
  def build_recurrence_rule(frequency, end_date)
    case frequency.to_s.downcase
    when 'daily'
      "RRULE:FREQ=DAILY;UNTIL=#{end_date.strftime('%Y%m%dT235959Z')}"
    when 'weekly'
      "RRULE:FREQ=WEEKLY;UNTIL=#{end_date.strftime('%Y%m%dT235959Z')}"
    when 'monthly'
      "RRULE:FREQ=MONTHLY;UNTIL=#{end_date.strftime('%Y%m%dT235959Z')}"
    else
      "RRULE:FREQ=DAILY;COUNT=1"
    end
  end
  
  def default_reminders
    Rails.application.config.google_calendar.defaults.reminder_minutes.map do |minutes|
      Google::Apis::CalendarV3::EventReminder.new(
        method: minutes >= 60 ? 'email' : 'popup',
        minutes: minutes
      )
    end
  end
end

# Include helpers globally
Rails.application.config.to_prepare do
  ActiveSupport.on_load(:active_record) do
    include GoogleCalendarHelpers
  end
end

Rails.logger.info "Google Calendar API initialized with application: #{Rails.application.config.google_calendar.application_name}" if Rails.application.config.google_calendar.logging.enabled
