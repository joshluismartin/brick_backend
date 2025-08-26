class CreateAchievements < ActiveRecord::Migration[7.1]
  def change
    create_table :achievements do |t|
      t.string :name, null: false
      t.string :description, null: false
      t.string :badge_type, null: false # habit_streak, milestone_progress, blueprint_completion, special
      t.string :category # fitness, business, education, creative, personal
      t.string :icon # emoji or icon identifier
      t.string :color, default: '#FFD700' # badge color
      t.integer :points, default: 0 # point value for gamification
      t.string :rarity, default: 'common' # common, rare, epic, legendary
      t.json :criteria # flexible criteria for earning the badge
      t.boolean :active, default: true
      t.integer :earned_count, default: 0 # how many times this badge has been earned
      
      t.timestamps
    end
    
    add_index :achievements, :badge_type
    add_index :achievements, :category
    add_index :achievements, :rarity
    add_index :achievements, :active
  end
end
