# frozen_string_literal: true

class AddEventOccurrencesCountToEvents < ActiveRecord::Migration[7.2]
  def up
    add_column :events, :event_occurrences_count, :integer, default: 0, null: false

    # Populate the counter cache for existing events
    Event.reset_column_information
    Event.unscoped.find_each do |event|
      Event.reset_counters(event.id, :event_occurrences)
    end
  end

  def down
    remove_column :events, :event_occurrences_count
  end
end
