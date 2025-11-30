# frozen_string_literal: true

class AddEmailRemindersEnabledToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :email_reminders_enabled, :boolean, default: true, null: false
  end
end
