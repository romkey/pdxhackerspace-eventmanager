# frozen_string_literal: true

class AddSlugToEvents < ActiveRecord::Migration[7.1]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    add_column :events, :slug, :string
    add_index :events, :slug, unique: true

    # Generate slugs for existing events
    Event.reset_column_information
    Event.find_each do |event|
      base_slug = event.title.parameterize
      slug = base_slug
      counter = 1

      while Event.where(slug: slug).where.not(id: event.id).exists?
        slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      event.update_column(:slug, slug)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    remove_index :events, :slug
    remove_column :events, :slug
  end
end
