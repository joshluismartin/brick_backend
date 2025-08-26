class CreateBlueprints < ActiveRecord::Migration[8.0]
  def change
    create_table :blueprints do |t|
      t.string :title
      t.text :description
      t.date :target_date
      t.string :status
      t.integer :user_id

      t.timestamps
    end
  end
end
