class AddSocialRemindersToSiteConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :site_configs, :social_reminders_enabled, :boolean, default: false, null: false
  end
end
