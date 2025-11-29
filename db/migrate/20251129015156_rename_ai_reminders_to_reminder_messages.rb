class RenameAiRemindersToReminderMessages < ActiveRecord::Migration[7.1]
  def change
    # Rename on events table
    rename_column :events, :ai_reminder_7d, :reminder_7d
    rename_column :events, :ai_reminder_1d, :reminder_1d

    # Rename on event_occurrences table
    rename_column :event_occurrences, :ai_reminder_7d, :reminder_7d
    rename_column :event_occurrences, :ai_reminder_1d, :reminder_1d
  end
end
