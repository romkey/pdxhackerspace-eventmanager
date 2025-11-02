class CreateEventOccurrences < ActiveRecord::Migration[7.0]
  def change
    create_table :event_occurrences do |t|
      t.references :event, null: false, foreign_key: true
      t.datetime :occurs_at, null: false
      t.string :status, default: 'active', null: false
      t.datetime :postponed_until
      t.text :cancellation_reason
      t.text :custom_description
      t.integer :duration_override

      t.timestamps
    end

    add_index :event_occurrences, :occurs_at
    add_index :event_occurrences, :status
    add_index :event_occurrences, [:event_id, :occurs_at]

    # Add max_occurrences to events table
    add_column :events, :max_occurrences, :integer, default: 5, null: false
  end
end
