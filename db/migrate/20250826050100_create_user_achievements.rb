class CreateUserAchievements < ActiveRecord::Migration[7.1]
  def change
    create_table :user_achievements do |t|
      t.references :achievement, null: false, foreign_key: true
      t.string :user_identifier # For now, we'll use a simple identifier until we add User model
      t.references :blueprint, null: true, foreign_key: true # Associated blueprint if applicable
      t.references :milestone, null: true, foreign_key: true # Associated milestone if applicable
      t.references :habit, null: true, foreign_key: true # Associated habit if applicable
      t.datetime :earned_at, null: false
      t.json :context # Additional context about how the badge was earned
      t.integer :streak_count # For streak-based achievements
      t.boolean :notified, default: false # Whether user has been notified
      
      t.timestamps
    end
    
    add_index :user_achievements, :user_identifier
    add_index :user_achievements, :earned_at
    add_index :user_achievements, [:user_identifier, :achievement_id], unique: false
    add_index :user_achievements, :notified
  end
end
