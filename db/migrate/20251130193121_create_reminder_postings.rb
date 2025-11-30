# frozen_string_literal: true

class CreateReminderPostings < ActiveRecord::Migration[7.2]
  def change
    create_table :reminder_postings do |t|
      t.references :event, null: false, foreign_key: true
      t.references :event_occurrence, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :post_uid
      t.string :post_url
      t.text :message
      t.string :reminder_type # 'slack', 'bluesky', 'instagram'
      t.datetime :posted_at, null: false
      t.datetime :deleted_at
      t.references :deleted_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :reminder_postings, :platform
    add_index :reminder_postings, :posted_at
    add_index :reminder_postings, %i[event_id posted_at]
  end
end
