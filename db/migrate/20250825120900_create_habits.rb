class CreateHabits < ActiveRecord::Migration[8.0]
  def change
    create_table :habits do |t|
      t.string :title, null: false, limit: 100
      t.text :description, limit: 500
      t.string :frequency, null: false, default: 'daily'
      t.string :status, null: false, default: 'pending'
      t.string :priority, null: false, default: 'medium'
      t.datetime :last_completed_at
      t.references :milestone, null: false, foreign_key: true

      t.timestamps
    end

    add_index :habits, :status
    add_index :habits, :frequency
    add_index :habits, :priority
    add_index :habits, [ :milestone_id, :frequency ]
    add_index :habits, :last_completed_at
  end
end
