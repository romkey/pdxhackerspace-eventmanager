# frozen_string_literal: true

class AddSlugToEventOccurrences < ActiveRecord::Migration[7.1]
  def up
    add_column :event_occurrences, :slug, :string
    add_index :event_occurrences, :slug, unique: true

    # Generate slugs for existing occurrences using raw SQL to avoid model scope issues
    execute <<-SQL.squish
      UPDATE event_occurrences eo
      SET slug = CONCAT(
        LOWER(REGEXP_REPLACE(REGEXP_REPLACE(e.title, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g')),
        '-',
        TO_CHAR(eo.occurs_at, 'YYYY-MM-DD'),
        '-',
        eo.id
      )
      FROM events e
      WHERE eo.event_id = e.id AND eo.slug IS NULL
    SQL
  end

  def down
    remove_index :event_occurrences, :slug
    remove_column :event_occurrences, :slug
  end
end
