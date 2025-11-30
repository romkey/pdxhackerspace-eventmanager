# frozen_string_literal: true

class AddSlugToEvents < ActiveRecord::Migration[7.1]
  def up
    add_column :events, :slug, :string
    add_index :events, :slug, unique: true

    # Generate slugs for existing events using raw SQL to avoid model scope issues
    execute <<-SQL.squish
      UPDATE events
      SET slug = CONCAT(
        LOWER(REGEXP_REPLACE(REGEXP_REPLACE(title, '[^a-zA-Z0-9\\s-]', '', 'g'), '\\s+', '-', 'g')),
        '-',
        id
      )
      WHERE slug IS NULL
    SQL
  end

  def down
    remove_index :events, :slug
    remove_column :events, :slug
  end
end
