# frozen_string_literal: true

class AddPermanentlyRelocatedToEvents < ActiveRecord::Migration[7.2]
  def up
    add_column :events, :permanently_relocated, :boolean, default: false, null: false unless column_exists?(:events, :permanently_relocated)
    add_column :events, :relocated_to, :text unless column_exists?(:events, :relocated_to)
  end

  def down
    remove_column :events, :permanently_relocated if column_exists?(:events, :permanently_relocated)
    remove_column :events, :relocated_to if column_exists?(:events, :relocated_to)
  end
end
