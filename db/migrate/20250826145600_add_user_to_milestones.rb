class AddUserToMilestones < ActiveRecord::Migration[8.0]
  def change
    # Add user_id column first (nullable)
    add_reference :milestones, :user, null: true, foreign_key: true
    
    # Assign existing milestones to the first user
    first_user_id = User.first.id
    Milestone.where(user_id: nil).update_all(user_id: first_user_id)
    
    # Now make it non-null
    change_column_null :milestones, :user_id, false
    
    # Add indexes for performance
    add_index :milestones, [:user_id, :status]
    add_index :milestones, [:user_id, :target_date]
  end
end
