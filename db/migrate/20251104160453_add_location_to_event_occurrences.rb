class AddLocationToEventOccurrences < ActiveRecord::Migration[7.1]
  def change
    add_reference :event_occurrences, :location, null: true, foreign_key: true
  end
end
