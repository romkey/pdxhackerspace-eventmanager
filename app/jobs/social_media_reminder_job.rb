class SocialMediaReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  REMINDER_OFFSETS = {
    7 => '1 week',
    1 => '1 day'
  }.freeze

  def perform
    site_config = SiteConfig.current
    return unless site_config.social_reminders_enabled?

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
                  .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?', start_time, end_time)
                  .where(event_occurrences: { status: 'active' })
                  .where(events: { status: 'active', draft: false, social_reminders: true })
                  .where(events: { visibility: %w[public members] })
                  .includes(:event)

    return if occurrences.empty?

    occurrences.each do |occurrence|
      next if occurrence.event.social_reminders? == false

      message = reminder_message(occurrence, label)
      SocialService.post_occurrence_reminder(occurrence, message)
    end
  end

  def build_social_message(occurrence, label)
    event = occurrence.event
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    time_str = occurrence.occurs_at.strftime('%I:%M %p')
    duration_str = format_duration(occurrence.duration)

    message = "Reminder: #{event.title} is happening #{label} from today!\\n"
    message += "#{date_str} at #{time_str} (#{duration_str})\\n"
    message += "#{event.description.truncate(250)}\\n" if event.description.present?
    message += "Location: #{event.location.name}\\n" if event.location.present?
    message += "More info: #{event.more_info_url}\\n" if event.more_info_url.present?

    host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
    protocol = ENV.fetch('RAILS_PROTOCOL', 'http')
    event_url = "#{protocol}://#{host}/events/#{event.id}"
    message += "View event: #{event_url}"

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
