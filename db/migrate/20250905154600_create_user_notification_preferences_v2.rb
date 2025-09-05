class CreateUserNotificationPreferencesV2 < ActiveRecord::Migration[7.0]
  def change
    # Check if table already exists before creating
    unless table_exists?(:user_notification_preferences)
      create_table :user_notification_preferences do |t|
        t.references :user, null: false, foreign_key: true
        t.boolean :habit_completion, default: true
        t.boolean :milestone_progress, default: true
        t.boolean :blueprint_completion, default: true
        t.boolean :daily_summary, default: true
        t.boolean :achievement_notifications, default: true
        t.boolean :habit_reminders, default: true
        t.string :email_frequency, default: 'immediate'
        t.string :reminder_time, default: '09:00'
        t.string :summary_time, default: '18:00'

        t.timestamps
      end

      # Check if index already exists before creating
      unless index_exists?(:user_notification_preferences, :user_id)
        add_index :user_notification_preferences, :user_id, unique: true
      end
    end
  end
end
