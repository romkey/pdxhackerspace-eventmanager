class AddVisibilityToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :visibility, :string, default: 'public', null: false
    add_index :events, :visibility
  end
end
