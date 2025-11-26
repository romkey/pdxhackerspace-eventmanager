class AddAiModelToSiteConfigs < ActiveRecord::Migration[7.1]
  def change
    add_column :site_configs, :ai_model, :string
  end
end

