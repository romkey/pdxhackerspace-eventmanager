class AddShortAndLongRemindersToEvents < ActiveRecord::Migration[7.1]
  def change
    # Rename existing reminder fields to short versions
    rename_column :events, :reminder_7d, :reminder_7d_short
    rename_column :events, :reminder_1d, :reminder_1d_short
    rename_column :event_occurrences, :reminder_7d, :reminder_7d_short
    rename_column :event_occurrences, :reminder_1d, :reminder_1d_short

    # Add long versions
    add_column :events, :reminder_7d_long, :text
    add_column :events, :reminder_1d_long, :text
    add_column :event_occurrences, :reminder_7d_long, :text
    add_column :event_occurrences, :reminder_1d_long, :text
  end
end
