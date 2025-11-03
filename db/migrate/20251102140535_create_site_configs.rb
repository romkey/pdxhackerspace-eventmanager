class CreateSiteConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :site_configs do |t|
      t.string :organization_name
      t.string :contact_email
      t.string :contact_phone
      t.text :footer_text

      t.timestamps
    end
  end
end
