# frozen_string_literal: true

# Posts a single Slack reminder for an occurrence
# Called by SlackEventReminderJob with staggered delays
class SlackPostReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  def perform(occurrence_id, label, days_ahead)
    site_config = SiteConfig.current
    return unless site_config.slack_enabled?

    occurrence = EventOccurrence.find_by(id: occurrence_id)
    return unless occurrence

    event = occurrence.event
    return unless event&.slack_announce?

    message = long_reminder_message(occurrence, label, days_ahead: days_ahead)
    if SlackService.post_occurrence_reminder(occurrence, message)
      Rails.logger.info "SlackPostReminderJob: Posted reminder for '#{event.title}' (#{label})"
    else
      Rails.logger.warn "SlackPostReminderJob: Failed to post reminder for '#{event.title}'"
    end
  end
end
