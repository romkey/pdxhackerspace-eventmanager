class AddLocationToSiteConfig < ActiveRecord::Migration[7.1]
  def change
    add_column :site_configs, :location_info, :text
    add_column :site_configs, :address, :string
  end
end

