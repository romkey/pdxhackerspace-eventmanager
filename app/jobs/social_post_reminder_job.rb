# frozen_string_literal: true

# Posts a single social media reminder for an occurrence
# Called by SocialMediaReminderJob with staggered delays
class SocialPostReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  def perform(occurrence_id, label, days_ahead)
    site_config = SiteConfig.current
    return unless site_config.social_reminders_enabled?

    occurrence = EventOccurrence.find_by(id: occurrence_id)
    return unless occurrence

    event = occurrence.event
    return unless event&.social_reminders?

    short_parts = reminder_message_with_link(occurrence, label, days_ahead: days_ahead, message_type: :short)
    long_parts = reminder_message_with_link(occurrence, label, days_ahead: days_ahead, message_type: :long)

    Rails.logger.info "SocialPostReminderJob: Posting reminder for '#{event.title}' (#{label})"
    SocialService.post_occurrence_reminder(occurrence, short_parts: short_parts, long_parts: long_parts,
                                                       reminder_type: label)
  end
end
