class AddDraftToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :draft, :boolean, default: false, null: false
  end
end

