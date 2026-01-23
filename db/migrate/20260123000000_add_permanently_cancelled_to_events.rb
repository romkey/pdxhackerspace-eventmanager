# frozen_string_literal: true

class AddPermanentlyCancelledToEvents < ActiveRecord::Migration[7.2]
  def up
    add_column :events, :permanently_cancelled, :boolean, default: false, null: false unless column_exists?(:events, :permanently_cancelled)
  end

  def down
    remove_column :events, :permanently_cancelled if column_exists?(:events, :permanently_cancelled)
  end
end
