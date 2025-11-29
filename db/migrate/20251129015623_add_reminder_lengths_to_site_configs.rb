class AddReminderLengthsToSiteConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :site_configs, :short_reminder_max_length, :integer, default: 300, null: false
    add_column :site_configs, :long_reminder_max_length, :integer, default: 800, null: false
  end
end
