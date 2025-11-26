module ReminderMessageBuilder
  def reminder_message(occurrence, label)
    case occurrence.status
    when 'cancelled'
      cancelled_message(occurrence)
    when 'postponed'
      postponed_message(occurrence)
    else
      active_message(occurrence, label)
    end
  end

  private

  def active_message(occurrence, label)
    event = occurrence.event
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    time_str = occurrence.occurs_at.strftime('%I:%M %p')
    duration_str = format_duration(occurrence.duration)

    message = "Reminder: #{event.title} is #{label} at PDX Hackerspace on #{date_str} at #{time_str} (#{duration_str})."
    if event.description.present?
      desc = event.description.length > 200 ? "#{event.description[0..197]}..." : event.description
      message += " #{desc}"
    end
    message += " Location: #{occurrence.event_location.name}." if occurrence.event_location.present?
    message += " #{event_url(event)}"
    message
  end

  def cancelled_message(occurrence)
    event = occurrence.event
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    time_str = occurrence.occurs_at.strftime('%I:%M %p')

    message = "⚠️ CANCELLED: #{event.title} scheduled for #{date_str} at #{time_str} has been cancelled."
    message += " Reason: #{occurrence.cancellation_reason}" if occurrence.cancellation_reason.present?
    message += " We apologize for any inconvenience."
    message += " #{event_url(event)}"
    message
  end

  def postponed_message(occurrence)
    event = occurrence.event
    original_date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    original_time_str = occurrence.occurs_at.strftime('%I:%M %p')

    message = "📅 POSTPONED: #{event.title} originally scheduled for #{original_date_str} at #{original_time_str} has been postponed."
    if occurrence.postponed_until.present?
      new_date_str = occurrence.postponed_until.strftime('%B %d, %Y')
      new_time_str = occurrence.postponed_until.strftime('%I:%M %p')
      message += " New date: #{new_date_str} at #{new_time_str}."
    end
    message += " #{event_url(event)}"
    message
  end

  def event_url(event)
    host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
    protocol = ENV.fetch('RAILS_PROTOCOL', 'http')
    "More info: #{protocol}://#{host}/events/#{event.id}"
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
