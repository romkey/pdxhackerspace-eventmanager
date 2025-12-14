class AddSignFeedToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :sign_feed, :boolean, default: true, null: false
  end
end
