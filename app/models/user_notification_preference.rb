class UserNotificationPreference < ApplicationRecord
  belongs_to :user

  validates :email_frequency, inclusion: { in: %w[immediate daily weekly] }
  validates :reminder_time, :summary_time, format: { with: /\A\d{2}:\d{2}\z/ }

  def self.for_user(user)
    find_or_create_by(user: user)
  end

  def to_hash
    {
      habit_completion: habit_completion,
      milestone_progress: milestone_progress,
      blueprint_completion: blueprint_completion,
      daily_summary: daily_summary,
      achievement_notifications: achievement_notifications,
      habit_reminders: habit_reminders,
      email_frequency: email_frequency,
      reminder_time: reminder_time,
      summary_time: summary_time
    }
  end
end
