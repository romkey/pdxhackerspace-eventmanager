class SlackEventReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  def perform
    site_config = SiteConfig.current
    return unless site_config.slack_enabled?

    webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
    return if webhook_url.blank?

    # Get all events happening today (9AM check, so events starting today)
    today = Date.current
    today_start = today.beginning_of_day
    today_end = today.end_of_day

    # Find all active occurrences happening today
    occurrences = EventOccurrence
                  .joins(:event)
                  .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?',
                         today_start, today_end)
                  .where(event_occurrences: { status: 'active' })
                  .where(events: { status: 'active', draft: false })
                  .where(events: { visibility: %w[public members] })
                  .where(events: { slack_announce: true })
                  .includes(:event)

    return if occurrences.empty?

    Rails.logger.info "SlackEventReminderJob: Found #{occurrences.count} events to announce today"

    occurrences.each do |occurrence|
      event = occurrence.event
      next unless event.slack_announce?

      message = reminder_message(occurrence, 'today')
      SlackService.post_message(message)
    end

    Rails.logger.info "SlackEventReminderJob: Completed posting #{occurrences.count} reminders"
  end

  private

  def build_reminder_message(event, occurrence)
    time_str = occurrence.occurs_at.strftime('%I:%M %p')
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    duration_str = format_duration(occurrence.duration)

    message = "📅 *Event Reminder: #{event.title}*\n"
    message += "📅 #{date_str} at #{time_str} (#{duration_str})\n"

    if event.description.present?
      # Truncate description if too long
      desc = event.description.length > 300 ? "#{event.description[0..297]}..." : event.description
      message += "\n#{desc}\n"
    end

    message += "\n📍 Location: #{event.location.name}\n" if event.location.present?

    message += "\n🔗 More info: #{event.more_info_url}\n" if event.more_info_url.present?

    # Add link to event page
    host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
    protocol = ENV.fetch('RAILS_PROTOCOL', 'http')
    event_url = "#{protocol}://#{host}/events/#{event.id}"
    message += "\n📋 View event: #{event_url}"

    message
  end

  def format_duration(minutes)
    hours = minutes / 60
    mins = minutes % 60

    if hours.positive? && mins.positive?
      "#{hours}h #{mins}m"
    elsif hours.positive?
      "#{hours}h"
    else
      "#{mins}m"
    end
  end
end
