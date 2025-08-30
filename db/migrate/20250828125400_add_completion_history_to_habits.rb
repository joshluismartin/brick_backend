class AddCompletionHistoryToHabits < ActiveRecord::Migration[8.0]
  def change
    add_column :habits, :completion_history, :text, array: true, default: []
    
    add_index :habits, :completion_history, using: 'gin'
  end
end
