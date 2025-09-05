class AddUserToUserAchievements < ActiveRecord::Migration[8.0]
  def change
    # Add user_id column first (nullable)
    add_reference :user_achievements, :user, null: true, foreign_key: true
    
    # Assign existing user_achievements to the first user based on user_identifier
    first_user_id = User.first.id
    UserAchievement.where(user_id: nil).update_all(user_id: first_user_id)
    
    # Now make it non-null
    change_column_null :user_achievements, :user_id, false
    
    # Add indexes for performance
    add_index :user_achievements, [:user_id, :earned_at]
    add_index :user_achievements, [:user_id, :achievement_id], unique: true, 
              name: 'index_user_achievements_on_user_and_achievement'
    
    # Remove the old user_identifier column after adding user_id
    remove_column :user_achievements, :user_identifier, :string
  end
end
