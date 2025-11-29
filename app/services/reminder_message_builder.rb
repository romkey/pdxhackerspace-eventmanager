module ReminderMessageBuilder
  LINK_TEXT = 'More info →'.freeze

  # Returns { text: "...", link_url: "...", link_text: "More info →" }
  # message_type: :short (for Bluesky) or :long (for Slack/Instagram)
  # days_ahead: 7 for 1-week reminder, 1 for 1-day reminder
  def reminder_message_with_link(occurrence, label, days_ahead: nil, message_type: :short)
    # Determine days_ahead from label if not provided
    days_ahead ||= label.include?('week') ? 7 : 1

    case occurrence.status
    when 'cancelled'
      cancelled_message_parts(occurrence, message_type)
    when 'postponed'
      postponed_message_parts(occurrence, message_type)
    else
      active_message_parts(occurrence, label, days_ahead, message_type)
    end
  end

  # Short message for Bluesky, Long for Slack/Instagram
  def short_reminder_message(occurrence, label, days_ahead: nil)
    parts = reminder_message_with_link(occurrence, label, days_ahead: days_ahead, message_type: :short)
    "#{parts[:text]} #{parts[:link_url]}"
  end

  def long_reminder_message(occurrence, label, days_ahead: nil)
    parts = reminder_message_with_link(occurrence, label, days_ahead: days_ahead, message_type: :long)
    "#{parts[:text]} #{parts[:link_url]}"
  end

  private

  def active_message_parts(occurrence, label, days_ahead, message_type)
    event = occurrence.event

    # Check for custom reminder message (occurrence's own or inherited from event)
    custom_message = get_custom_message(occurrence, days_ahead, message_type)

    message = custom_message.presence || generate_default_message(occurrence, label, message_type)

    { text: message, link_url: event_url_for(event), link_text: LINK_TEXT }
  end

  def get_custom_message(occurrence, days_ahead, message_type)
    if message_type == :short
      days_ahead == 7 ? occurrence.effective_reminder_7d_short : occurrence.effective_reminder_1d_short
    else
      days_ahead == 7 ? occurrence.effective_reminder_7d_long : occurrence.effective_reminder_1d_long
    end
  end

  def generate_default_message(occurrence, label, message_type)
    event = occurrence.event
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    time_str = occurrence.occurs_at.strftime('%I:%M %p')
    duration_str = format_duration(occurrence.duration)

    if message_type == :short
      # Short message for Bluesky
      message = "#{event.title} is #{label} at PDX Hackerspace on #{date_str} at #{time_str}."
      message += " Join us!" if message.length < 200
    else
      # Long message for Slack/Instagram
      message = "📅 #{event.title} is #{label} at PDX Hackerspace!\n"
      message += "🕐 #{date_str} at #{time_str} (#{duration_str})\n"
      message += "📍 #{occurrence.event_location.name}\n" if occurrence.event_location.present?
      if event.description.present?
        desc = event.description.length > 400 ? "#{event.description[0..397]}..." : event.description
        message += "\n#{desc}"
      end
    end

    message
  end

  def cancelled_message_parts(occurrence, message_type)
    event, date_str, time_str = occurrence_info(occurrence)
    msg = message_type == :short ? short_cancelled(event, date_str, time_str) : long_cancelled(event, date_str, time_str, occurrence)
    { text: msg, link_url: event_url_for(event), link_text: LINK_TEXT }
  end

  def short_cancelled(event, date_str, time_str)
    msg = "⚠️ CANCELLED: #{event.title} on #{date_str} at #{time_str}."
    msg.length < 250 ? "#{msg} Sorry!" : msg
  end

  def long_cancelled(event, date_str, time_str, occurrence)
    msg = "⚠️ CANCELLED: #{event.title} scheduled for #{date_str} at #{time_str} has been cancelled."
    msg += "\nReason: #{occurrence.cancellation_reason}" if occurrence.cancellation_reason.present?
    "#{msg}\nWe apologize for any inconvenience."
  end

  def postponed_message_parts(occurrence, message_type)
    event, date_str, time_str = occurrence_info(occurrence)
    msg = message_type == :short ? short_postponed(event, date_str, occurrence) : long_postponed(event, date_str, time_str, occurrence)
    { text: msg, link_url: event_url_for(event), link_text: LINK_TEXT }
  end

  def short_postponed(event, date_str, occurrence)
    msg = "📅 POSTPONED: #{event.title} (was #{date_str})."
    occurrence.postponed_until.present? ? "#{msg} New date: #{occurrence.postponed_until.strftime('%B %d')}." : msg
  end

  def long_postponed(event, date_str, time_str, occurrence)
    msg = "📅 POSTPONED: #{event.title} originally scheduled for #{date_str} at #{time_str} has been postponed."
    return msg if occurrence.postponed_until.blank?

    "#{msg}\nNew date: #{occurrence.postponed_until.strftime('%B %d, %Y at %I:%M %p')}."
  end

  def occurrence_info(occurrence)
    [occurrence.event, occurrence.occurs_at.strftime('%B %d, %Y'), occurrence.occurs_at.strftime('%I:%M %p')]
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
