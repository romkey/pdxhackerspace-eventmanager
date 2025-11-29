# frozen_string_literal: true

class ImproveSchemaIndexesAndConstraints < ActiveRecord::Migration[7.1]
  # rubocop:disable Rails/SkipsModelValidations, Rails/BulkChangeTable
  def up
    # 1. Fix event_journals.occurrence_id to be a proper bigint foreign key
    # First, nullify any orphaned occurrence_id references (occurrences that were deleted)
    execute <<~SQL.squish
      UPDATE event_journals
      SET occurrence_id = NULL
      WHERE occurrence_id IS NOT NULL
        AND occurrence_id NOT IN (SELECT id FROM event_occurrences)
    SQL

    change_column :event_journals, :occurrence_id, :bigint
    add_foreign_key :event_journals, :event_occurrences, column: :occurrence_id, on_delete: :nullify

    # 2. Add composite index on users for OAuth lookups (provider + uid)
    add_index :users, %i[provider uid],
              unique: true,
              where: "provider IS NOT NULL AND uid IS NOT NULL",
              name: "index_users_on_provider_and_uid"

    # 3. Add composite index on event_occurrences for status + occurs_at (common query pattern)
    add_index :event_occurrences, %i[status occurs_at], name: "index_event_occurrences_on_status_and_occurs_at"

    # 4. Add index on event_journals.action for filtering by action type
    add_index :event_journals, :action, name: "index_event_journals_on_action"

    # 5. Add deleted_at for soft deletes on events
    add_column :events, :deleted_at, :datetime
    add_index :events, :deleted_at, name: "index_events_on_deleted_at"

    # 6. Add deleted_at for soft deletes on event_occurrences
    add_column :event_occurrences, :deleted_at, :datetime
    add_index :event_occurrences, :deleted_at, name: "index_event_occurrences_on_deleted_at"

    # 7. Add check constraints for enum columns (PostgreSQL)
    add_check_constraint :events, "status IN ('active', 'postponed', 'cancelled')",
                         name: "events_status_check"
    add_check_constraint :events, "visibility IN ('public', 'members', 'private')",
                         name: "events_visibility_check"
    add_check_constraint :events, "open_to IN ('public', 'members', 'private')",
                         name: "events_open_to_check"
    add_check_constraint :events, "recurrence_type IN ('once', 'weekly', 'monthly', 'custom')",
                         name: "events_recurrence_type_check"

    add_check_constraint :event_occurrences, "status IN ('active', 'postponed', 'cancelled')",
                         name: "event_occurrences_status_check"

    add_check_constraint :users, "role IN ('user', 'admin')",
                         name: "users_role_check"

    # 8. Ensure site_configs is a singleton (only one row with id = 1)
    add_check_constraint :site_configs, "id = 1", name: "site_configs_singleton"

    # 9. Set NOT NULL on events.status (update any nulls first)
    # Using update_all is intentional in migrations to avoid model callbacks
    Event.where(status: nil).update_all(status: 'active')
    change_column_null :events, :status, false

    # 10. Set NOT NULL on events.recurrence_type (update any nulls first)
    Event.where(recurrence_type: nil).update_all(recurrence_type: 'once')
    change_column_null :events, :recurrence_type, false

    # 11. Add full-text search support using pg_trgm extension and GIN indexes
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    execute <<~SQL.squish
      CREATE INDEX index_events_on_title_trgm ON events USING gin (title gin_trgm_ops);
    SQL

    execute <<~SQL.squish
      CREATE INDEX index_events_on_description_trgm ON events USING gin (description gin_trgm_ops);
    SQL
  end

  def down
    # Remove full-text search indexes
    execute <<~SQL.squish
      DROP INDEX IF EXISTS index_events_on_title_trgm;
    SQL

    execute <<~SQL.squish
      DROP INDEX IF EXISTS index_events_on_description_trgm;
    SQL

    # Remove NOT NULL constraints
    change_column_null :events, :recurrence_type, true
    change_column_null :events, :status, true

    # Remove check constraints
    remove_check_constraint :site_configs, name: "site_configs_singleton"
    remove_check_constraint :users, name: "users_role_check"
    remove_check_constraint :event_occurrences, name: "event_occurrences_status_check"
    remove_check_constraint :events, name: "events_recurrence_type_check"
    remove_check_constraint :events, name: "events_open_to_check"
    remove_check_constraint :events, name: "events_visibility_check"
    remove_check_constraint :events, name: "events_status_check"

    # Remove deleted_at columns
    remove_index :event_occurrences, name: "index_event_occurrences_on_deleted_at"
    remove_column :event_occurrences, :deleted_at

    remove_index :events, name: "index_events_on_deleted_at"
    remove_column :events, :deleted_at

    # Remove indexes
    remove_index :event_journals, name: "index_event_journals_on_action"
    remove_index :event_occurrences, name: "index_event_occurrences_on_status_and_occurs_at"
    remove_index :users, name: "index_users_on_provider_and_uid"

    # Remove foreign key and revert column type
    remove_foreign_key :event_journals, :event_occurrences
    change_column :event_journals, :occurrence_id, :integer
  end
  # rubocop:enable Rails/SkipsModelValidations, Rails/BulkChangeTable
end
