class AddRequiresMaskToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :requires_mask, :boolean, default: false, null: false
  end
end

