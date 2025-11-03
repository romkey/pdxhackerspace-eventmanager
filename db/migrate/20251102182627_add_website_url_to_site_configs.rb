class AddWebsiteUrlToSiteConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :site_configs, :website_url, :string
  end
end
