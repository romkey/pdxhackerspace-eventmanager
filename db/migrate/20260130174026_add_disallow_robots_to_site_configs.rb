class AddDisallowRobotsToSiteConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :site_configs, :disallow_robots, :boolean, default: false, null: false
  end
end
