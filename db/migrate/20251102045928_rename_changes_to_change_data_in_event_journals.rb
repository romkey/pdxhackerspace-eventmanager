class RenameChangesToChangeDataInEventJournals < ActiveRecord::Migration[7.0]
  def change
    rename_column :event_journals, :changes, :change_data
  end
end
