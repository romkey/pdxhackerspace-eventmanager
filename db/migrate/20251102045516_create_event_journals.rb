class CreateEventJournals < ActiveRecord::Migration[7.0]
  def change
    create_table :event_journals do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.jsonb :changes, default: {}
      t.integer :occurrence_id

      t.timestamps
    end

    add_index :event_journals, :occurrence_id
    add_index :event_journals, :created_at
    add_index :event_journals, [:event_id, :created_at]
  end
end
