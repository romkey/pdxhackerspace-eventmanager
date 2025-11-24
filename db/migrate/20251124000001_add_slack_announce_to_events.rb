class AddSlackAnnounceToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :slack_announce, :boolean, default: true, null: false
  end
end

