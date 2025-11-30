# frozen_string_literal: true

class AddEmailTestModeToSiteConfigs < ActiveRecord::Migration[7.2]
  def change
    change_table :site_configs, bulk: true do |t|
      t.boolean :email_test_mode_enabled, default: false, null: false
      t.string :email_test_mode_address
    end
  end
end
