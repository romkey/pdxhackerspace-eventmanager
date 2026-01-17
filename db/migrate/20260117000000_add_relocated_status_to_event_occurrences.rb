# frozen_string_literal: true

class AddRelocatedStatusToEventOccurrences < ActiveRecord::Migration[7.2]
  def up
    # Add relocated_to field to store new location description
    add_column :event_occurrences, :relocated_to, :text

    # Update the status check constraint to include 'relocated'
    remove_check_constraint :event_occurrences, name: 'event_occurrences_status_check'
    add_check_constraint :event_occurrences,
                         "status IN ('active', 'postponed', 'cancelled', 'relocated')",
                         name: 'event_occurrences_status_check'
  end

  def down
    # Revert any relocated occurrences to cancelled before removing the constraint
    execute "UPDATE event_occurrences SET status = 'cancelled' WHERE status = 'relocated'"

    remove_check_constraint :event_occurrences, name: 'event_occurrences_status_check'
    add_check_constraint :event_occurrences,
                         "status IN ('active', 'postponed', 'cancelled')",
                         name: 'event_occurrences_status_check'

    remove_column :event_occurrences, :relocated_to
  end
end
