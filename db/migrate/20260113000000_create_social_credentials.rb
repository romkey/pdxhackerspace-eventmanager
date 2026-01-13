# frozen_string_literal: true

class CreateSocialCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :social_credentials do |t|
      t.string :platform, null: false
      t.text :access_token, null: false
      t.datetime :expires_at
      t.text :refresh_token
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :social_credentials, :platform, unique: true
  end
end
