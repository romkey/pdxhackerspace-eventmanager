class EventJournal < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :occurrence, class_name: 'EventOccurrence', optional: true

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  # Log an event change
  def self.log_event_change(event, user, action, changed_attributes = {})
    create!(
      event: event,
      user: user,
      action: action,
      change_data: changed_attributes
    )
  end

  # Log an occurrence change
  def self.log_occurrence_change(occurrence, user, action, changed_attributes = {})
    create!(
      event: occurrence.event,
      user: user,
      action: action,
      occurrence_id: occurrence.id,
      change_data: changed_attributes
    )
  end

  # Human-readable change summary
  def summary
    case action
    when 'created'
      occurrence_id ? "Created occurrence for #{occurrence_date}" : "Created event"
    when 'updated'
      if change_data.present?
        changed_fields = change_data.keys.join(', ')
        occurrence_id ? "Updated occurrence (#{changed_fields})" : "Updated event (#{changed_fields})"
      else
        occurrence_id ? "Updated occurrence" : "Updated event"
      end
    when 'cancelled'
      occurrence_id ? "Cancelled occurrence for #{occurrence_date}" : "Cancelled event"
    when 'postponed'
      occurrence_id ? "Postponed occurrence for #{occurrence_date}" : "Postponed event"
    when 'reactivated'
      occurrence_id ? "Reactivated occurrence for #{occurrence_date}" : "Reactivated event"
    when 'deleted'
      occurrence_id ? "Deleted occurrence for #{occurrence_date}" : "Deleted event"
    when 'host_added'
      added_user_email = change_data['added_host']
      "Added #{added_user_email} as co-host"
    when 'host_removed'
      removed_user_email = change_data['removed_host']
      "Removed #{removed_user_email} as co-host"
    when 'banner_added'
      if change_data['banner_image'].present?
        filename = change_data['banner_image']['filename']
        size = change_data['banner_image']['size']
        occurrence_id ? "Added banner image to occurrence: #{filename} (#{size})" : "Added banner image: #{filename} (#{size})"
      else
        occurrence_id ? "Added banner image to occurrence" : "Added banner image"
      end
    when 'banner_removed'
      occurrence_id ? "Removed banner image from occurrence" : "Removed banner image"
    else
      action.titleize
    end
  end

  # Get formatted changes for display
  def formatted_changes
    return {} if change_data.blank?

    change_data.transform_keys do |key|
      key.to_s.titleize
    end
  end

  private

  def occurrence_date
    occurrence&.occurs_at&.strftime('%B %d, %Y') || 'Unknown date'
  end
end
