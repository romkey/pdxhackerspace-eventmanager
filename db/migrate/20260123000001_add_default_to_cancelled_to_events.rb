# frozen_string_literal: true

class AddDefaultToCancelledToEvents < ActiveRecord::Migration[7.2]
  def up
    add_column :events, :default_to_cancelled, :boolean, default: false, null: false unless column_exists?(:events, :default_to_cancelled)
  end

  def down
    remove_column :events, :default_to_cancelled if column_exists?(:events, :default_to_cancelled)
  end
end
