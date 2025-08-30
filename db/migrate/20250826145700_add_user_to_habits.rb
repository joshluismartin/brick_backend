class AddUserToHabits < ActiveRecord::Migration[8.0]
  def change
    # Add user_id column first (nullable)
    add_reference :habits, :user, null: true, foreign_key: true
    
    # Assign existing habits to the first user
    first_user_id = User.first.id
    Habit.where(user_id: nil).update_all(user_id: first_user_id)
    
    # Now make it non-null
    change_column_null :habits, :user_id, false
    
    # Add indexes for performance
    add_index :habits, [:user_id, :status]
    add_index :habits, [:user_id, :frequency]
    add_index :habits, [:user_id, :created_at]
  end
end
