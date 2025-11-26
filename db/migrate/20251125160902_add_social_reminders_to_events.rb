class AddSocialRemindersToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :social_reminders, :boolean, default: true, null: false
  end
end
