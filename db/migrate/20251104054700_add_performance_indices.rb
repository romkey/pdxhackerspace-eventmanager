class AddPerformanceIndices < ActiveRecord::Migration[7.1]
  def change
    # Add index on events.start_time for homepage and calendar queries
    add_index :events, :start_time, if_not_exists: true

    # Add index on recurrence_type for recurring event queries (used by Sidekiq job)
    add_index :events, :recurrence_type, if_not_exists: true

    # Composite index for common query pattern: active events with visibility
    add_index :events, [:status, :visibility], if_not_exists: true

    # Composite index for finding active events ordered by start time
    add_index :events, [:status, :start_time], if_not_exists: true
    
    # Add index on users.role for admin/authorization queries
    add_index :users, :role, if_not_exists: true
  end
end


