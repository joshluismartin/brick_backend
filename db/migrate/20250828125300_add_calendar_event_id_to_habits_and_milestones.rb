class AddCalendarEventIdToHabitsAndMilestones < ActiveRecord::Migration[8.0]
  def change
    add_column :habits, :calendar_event_id, :string
    add_column :milestones, :calendar_event_id, :string
    
    add_index :habits, :calendar_event_id
    add_index :milestones, :calendar_event_id
  end
end
