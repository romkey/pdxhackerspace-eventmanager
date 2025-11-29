module ReminderMessageBuilder
  LINK_TEXT = 'More info →'.freeze

  # Returns { text: "...", link_url: "...", link_text: "More info →" }
  # The link_text appears at the end of the message and can be made clickable via facets
  def reminder_message_with_link(occurrence, label)
    case occurrence.status
    when 'cancelled'
      cancelled_message_parts(occurrence)
    when 'postponed'
      postponed_message_parts(occurrence)
    else
      active_message_parts(occurrence, label)
    end
  end

  # Legacy method for Slack and other platforms that support inline URLs
  def reminder_message(occurrence, label)
    parts = reminder_message_with_link(occurrence, label)
    "#{parts[:text]} #{parts[:link_url]}"
  end

  private

  def active_message_parts(occurrence, label)
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

    { text: message, link_url: event_url_for(event), link_text: LINK_TEXT }
  end

  def cancelled_message_parts(occurrence)
    event = occurrence.event
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    time_str = occurrence.occurs_at.strftime('%I:%M %p')

    message = "⚠️ CANCELLED: #{event.title} scheduled for #{date_str} at #{time_str} has been cancelled."
    message += " Reason: #{occurrence.cancellation_reason}" if occurrence.cancellation_reason.present?
    message += " We apologize for any inconvenience."

    { text: message, link_url: event_url_for(event), link_text: LINK_TEXT }
  end

  def postponed_message_parts(occurrence)
    event = occurrence.event
    original_date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    original_time_str = occurrence.occurs_at.strftime('%I:%M %p')

    message = "📅 POSTPONED: #{event.title} originally scheduled for #{original_date_str} at #{original_time_str} has been postponed."
    if occurrence.postponed_until.present?
      new_date_str = occurrence.postponed_until.strftime('%B %d, %Y')
      new_time_str = occurrence.postponed_until.strftime('%I:%M %p')
      message += " New date: #{new_date_str} at #{new_time_str}."
    end

    { text: message, link_url: event_url_for(event), link_text: LINK_TEXT }
  end

  def event_url_for(event)
    host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
    protocol = ENV.fetch('RAILS_PROTOCOL', 'http')
    "#{protocol}://#{host}/events/#{event.slug}"
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
