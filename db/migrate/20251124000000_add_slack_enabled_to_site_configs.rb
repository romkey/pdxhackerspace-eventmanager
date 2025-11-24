class AddSlackEnabledToSiteConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :site_configs, :slack_enabled, :boolean, default: false, null: false
  end
end

