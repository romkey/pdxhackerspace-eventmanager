module ReminderMessageBuilder
  def reminder_message(occurrence, label)
    event = occurrence.event
    date_str = occurrence.occurs_at.strftime('%B %d, %Y')
    time_str = occurrence.occurs_at.strftime('%I:%M %p')
    duration_str = format_duration(occurrence.duration)

    message = "Reminder: #{event.title} is #{label} at PDX Hackerspace on #{date_str} at #{time_str} (#{duration_str})."
    if event.description.present?
      desc = event.description.length > 200 ? "#{event.description[0..197]}..." : event.description
      message += " #{desc}"
    end
    message += " Location: #{event.location.name}." if event.location.present?
    host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
    protocol = ENV.fetch('RAILS_PROTOCOL', 'http')
    event_url = "#{protocol}://#{host}/events/#{event.id}"
    message += " More info: #{event_url}"
    message
  end

  private

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
