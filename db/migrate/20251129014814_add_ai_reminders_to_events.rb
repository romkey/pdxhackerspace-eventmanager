class AddAiRemindersToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :ai_reminder_7d, :text
    add_column :events, :ai_reminder_1d, :text
  end
end
