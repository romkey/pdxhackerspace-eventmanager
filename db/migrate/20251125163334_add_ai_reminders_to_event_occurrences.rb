class AddAiRemindersToEventOccurrences < ActiveRecord::Migration[7.1]
  def change
    add_column :event_occurrences, :ai_reminder_7d, :text
    add_column :event_occurrences, :ai_reminder_1d, :text
  end
end
