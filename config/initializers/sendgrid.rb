# SendGrid Email API Configuration
require 'sendgrid-ruby'

Rails.application.configure do
  # SendGrid API settings
  config.sendgrid = ActiveSupport::OrderedOptions.new
  
  # Application name for email sending
  config.sendgrid.application_name = 'BRICK Goal Achievement App'
  
  # API key from environment variables or Rails credentials
  config.sendgrid.api_key = ENV['SENDGRID_API_KEY'] || Rails.application.credentials.sendgrid&.api_key
  
  # Default sender information
  config.sendgrid.from_email = ENV['SENDGRID_FROM_EMAIL'] || 'noreply@brickgoals.com'
  config.sendgrid.from_name = ENV['SENDGRID_FROM_NAME'] || 'BRICK Goal Achievement'
  
  # Email template settings
  config.sendgrid.use_templates = ENV['SENDGRID_USE_TEMPLATES'] == 'true'
  
  # Template IDs (if using SendGrid templates in production)
  config.sendgrid.templates = {
    habit_completion: ENV['SENDGRID_TEMPLATE_HABIT_COMPLETION'],
    milestone_progress: ENV['SENDGRID_TEMPLATE_MILESTONE_PROGRESS'],
    blueprint_completion: ENV['SENDGRID_TEMPLATE_BLUEPRINT_COMPLETION'],
    daily_summary: ENV['SENDGRID_TEMPLATE_DAILY_SUMMARY'],
    achievement_notification: ENV['SENDGRID_TEMPLATE_ACHIEVEMENT'],
    habit_reminder: ENV['SENDGRID_TEMPLATE_HABIT_REMINDER']
  }
end

# Initialize SendGrid API client
if Rails.application.config.sendgrid.api_key.present?
  Rails.logger.info "SendGrid API initialized successfully"
else
  Rails.logger.warn "SendGrid API key not found. Set SENDGRID_API_KEY environment variable to enable email notifications."
end

# SendGrid webhook configuration (for tracking email events)
# You can set up webhooks in SendGrid dashboard to track:
# - delivered, opened, clicked, bounced, dropped, etc.
Rails.application.configure do
  config.sendgrid.webhook_url = ENV['SENDGRID_WEBHOOK_URL']
  config.sendgrid.webhook_secret = ENV['SENDGRID_WEBHOOK_SECRET']
end
