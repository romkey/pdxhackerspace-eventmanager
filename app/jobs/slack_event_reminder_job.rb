class SlackEventReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  REMINDER_OFFSETS = {
    7 => '1 week',
    1 => '1 day'
  }.freeze

  def perform
    site_config = SiteConfig.current
    return unless site_config.slack_enabled?

    webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
    return if webhook_url.blank?

    REMINDER_OFFSETS.each do |days_ahead, label|
      post_reminders_for_days(days_ahead, label)
    end
  end

  private

  def post_reminders_for_days(days_ahead, label)
    target_date = Date.current + days_ahead.days
    start_time = target_date.beginning_of_day
    end_time = target_date.end_of_day

    occurrences = EventOccurrence
                  .joins(:event)
                  .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?',
                         start_time, end_time)
                  .where(event_occurrences: { status: %w[active cancelled postponed] })
                  .where(events: { status: 'active', draft: false })
                  .where(events: { visibility: %w[public members] })
                  .where(events: { slack_announce: true })
                  .includes(:event)

    return if occurrences.empty?

    Rails.logger.info "SlackEventReminderJob: Found #{occurrences.count} events #{label} away"

    occurrences.each do |occurrence|
      event = occurrence.event
      next unless event.slack_announce?

      message = reminder_message(occurrence, label, days_ahead: days_ahead)
      SlackService.post_occurrence_reminder(occurrence, message)
    end

    Rails.logger.info "SlackEventReminderJob: Completed posting #{occurrences.count} reminders for #{label}"
  end
end
