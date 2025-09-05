class AddMissingAttributesToBlueprints < ActiveRecord::Migration[8.0]
  def change
    add_column :blueprints, :category, :string
    add_column :blueprints, :priority, :string
    add_column :blueprints, :spotify_playlist_id, :string
    
    # Add indexes for better query performance
    add_index :blueprints, :category
    add_index :blueprints, :priority
    add_index :blueprints, :status
  end
end
