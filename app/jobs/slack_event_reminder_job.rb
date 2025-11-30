class SlackEventReminderJob < ApplicationJob
  queue_as :default

  REMINDER_OFFSETS = {
    7 => '1 week',
    1 => '1 day'
  }.freeze

  # Delay between posts to prevent Slack from merging messages
  POST_DELAY_MINUTES = 5

  def perform
    site_config = SiteConfig.current
    return unless site_config.slack_enabled?

    webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
    return if webhook_url.blank?

    post_index = 0
    REMINDER_OFFSETS.each do |days_ahead, label|
      post_index = schedule_reminders_for_days(days_ahead, label, post_index)
    end
  end

  private

  def schedule_reminders_for_days(days_ahead, label, start_index)
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

    return start_index if occurrences.empty?

    Rails.logger.info "SlackEventReminderJob: Scheduling #{occurrences.count} reminders for #{label}"

    current_index = start_index
    occurrences.each do |occurrence|
      delay_minutes = current_index * POST_DELAY_MINUTES
      SlackPostReminderJob.set(wait: delay_minutes.minutes).perform_later(occurrence.id, label, days_ahead)
      current_index += 1
    end

    Rails.logger.info "SlackEventReminderJob: Scheduled #{occurrences.count} reminders for #{label} (staggered over #{(occurrences.count - 1) * POST_DELAY_MINUTES} minutes)"
    current_index
  end
end
