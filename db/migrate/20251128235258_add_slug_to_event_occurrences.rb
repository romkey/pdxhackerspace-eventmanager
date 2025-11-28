# frozen_string_literal: true

class AddSlugToEventOccurrences < ActiveRecord::Migration[7.1]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    add_column :event_occurrences, :slug, :string
    add_index :event_occurrences, :slug, unique: true

    # Generate slugs for existing occurrences
    EventOccurrence.reset_column_information
    EventOccurrence.includes(:event).find_each do |occurrence|
      event_slug = occurrence.event.title.parameterize
      date_slug = occurrence.occurs_at.strftime('%Y-%m-%d')
      base_slug = "#{event_slug}-#{date_slug}"
      slug = base_slug
      counter = 1

      while EventOccurrence.where(slug: slug).where.not(id: occurrence.id).exists?
        slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      occurrence.update_column(:slug, slug)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down
    remove_index :event_occurrences, :slug
    remove_column :event_occurrences, :slug
  end
end
