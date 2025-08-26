class CreateMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :milestones do |t|
      t.string :title, null: false, limit: 100
      t.text :description, limit: 500
      t.date :target_date, null: false
      t.string :status, null: false, default: 'pending'
      t.string :priority, null: false, default: 'medium'
      t.references :blueprint, null: false, foreign_key: true

      t.timestamps
    end

    add_index :milestones, :status
    add_index :milestones, :priority
    add_index :milestones, :target_date
    add_index :milestones, [ :blueprint_id, :target_date ]
  end
end
