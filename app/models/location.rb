class Location < ApplicationRecord
  has_many :events, dependent: :nullify
  has_many :event_occurrences, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :name, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true

  scope :alphabetical, -> { order(:name) }

  def self.default
    find_by(name: 'Main Space') || first
  end
end
