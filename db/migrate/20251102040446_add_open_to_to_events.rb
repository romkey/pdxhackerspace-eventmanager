class AddOpenToToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :open_to, :string, default: 'public', null: false
    add_index :events, :open_to
  end
end
