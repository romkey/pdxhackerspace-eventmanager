class AddCanCreateEventsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :can_create_events, :boolean, default: false, null: false
  end
end

