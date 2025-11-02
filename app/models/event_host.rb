class EventHost < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :user_id, uniqueness: { scope: :event_id, message: "is already a host for this event" }
end
