class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.datetime :start_time, null: false
      t.integer :duration, default: 60 # duration in minutes
      t.text :recurrence_rule # JSON string for IceCube schedule
      t.string :recurrence_type # 'once', 'weekly', 'monthly', 'custom'
      t.string :status, default: 'active' # 'active', 'postponed', 'cancelled'
      t.datetime :postponed_until
      t.text :cancellation_reason
      t.string :ical_token # unique token for public ical feed

      t.timestamps
    end

    add_index :events, :ical_token, unique: true
    add_index :events, :status
  end
end
