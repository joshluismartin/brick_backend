class AddUserToBlueprints < ActiveRecord::Migration[8.0]
  def change
    # First, ensure we have at least one user
    unless User.exists?
      User.create!(
        email: 'admin@brickgoals.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end
    
    # Get the first user ID
    first_user_id = User.first.id
    
    # Update all blueprints with NULL user_id
    Blueprint.where(user_id: nil).update_all(user_id: first_user_id)
    
    # Make user_id not null and add foreign key constraint
    change_column_null :blueprints, :user_id, false
    add_foreign_key :blueprints, :users, column: :user_id
    
    # Add indexes for performance (only for existing columns)
    add_index :blueprints, [:user_id, :status]
    add_index :blueprints, [:user_id, :created_at]
  end
end
