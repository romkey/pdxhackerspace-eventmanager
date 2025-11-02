class CreateEventHosts < ActiveRecord::Migration[7.0]
  def change
    create_table :event_hosts do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # Ensure a user can only be a host once per event
    add_index :event_hosts, [:event_id, :user_id], unique: true
  end
end
