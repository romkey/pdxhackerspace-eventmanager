class AddMatomoToSiteConfigs < ActiveRecord::Migration[7.2]
  def change
    change_table :site_configs, bulk: true do |t|
      t.boolean :matomo_enabled, default: false, null: false
      t.string :matomo_url
      t.string :matomo_site_id
    end
  end
end
