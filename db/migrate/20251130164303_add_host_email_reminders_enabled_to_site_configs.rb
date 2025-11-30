# frozen_string_literal: true

class AddHostEmailRemindersEnabledToSiteConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :site_configs, :host_email_reminders_enabled, :boolean, default: true, null: false
  end
end
