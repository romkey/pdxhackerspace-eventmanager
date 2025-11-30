# frozen_string_literal: true

class ReminderPosting < ApplicationRecord
  belongs_to :event
  belongs_to :event_occurrence
  belongs_to :deleted_by, class_name: 'User', optional: true

  validates :platform, presence: true, inclusion: { in: %w[slack bluesky instagram] }
  validates :posted_at, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :recent_first, -> { order(posted_at: :desc) }

  # Check if this posting can be deleted/retracted from the service
  def deletable?
    deleted_at.nil? && post_uid.present? && platform == 'bluesky'
  end

  def deleted?
    deleted_at.present?
  end

  def platform_display_name
    case platform
    when 'slack' then 'Slack'
    when 'bluesky' then 'Bluesky'
    when 'instagram' then 'Instagram'
    else platform.titleize
    end
  end

  # Mark as deleted (soft delete)
  def mark_deleted!(user)
    update!(deleted_at: Time.current, deleted_by: user)
  end
end
