# frozen_string_literal: true

class AddRelocatedStatusToEventOccurrences < ActiveRecord::Migration[7.2]
  def up
    # Add relocated_to field to store new location description (idempotent)
    add_column :event_occurrences, :relocated_to, :text unless column_exists?(:event_occurrences, :relocated_to)

    # Update the status check constraint to include 'relocated' (idempotent)
    # First check if constraint exists and needs updating
    remove_check_constraint :event_occurrences, name: 'event_occurrences_status_check' if constraint_exists?('event_occurrences_status_check')

    # Add the updated constraint with 'relocated' status
    add_check_constraint :event_occurrences,
                         "status IN ('active', 'postponed', 'cancelled', 'relocated')",
                         name: 'event_occurrences_status_check'
  end

  def down
    # Revert any relocated occurrences to cancelled before removing the constraint
    execute "UPDATE event_occurrences SET status = 'cancelled' WHERE status = 'relocated'"

    remove_check_constraint :event_occurrences, name: 'event_occurrences_status_check' if constraint_exists?('event_occurrences_status_check')

    add_check_constraint :event_occurrences,
                         "status IN ('active', 'postponed', 'cancelled')",
                         name: 'event_occurrences_status_check'

    remove_column :event_occurrences, :relocated_to if column_exists?(:event_occurrences, :relocated_to)
  end

  private

  def constraint_exists?(constraint_name)
    query = <<~SQL.squish
      SELECT 1 FROM pg_constraint
      WHERE conname = '#{constraint_name}'
    SQL
    ActiveRecord::Base.connection.select_value(query).present?
  end
end
