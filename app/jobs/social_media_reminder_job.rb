class SocialMediaReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  REMINDER_OFFSETS = {
    6 => '6 days',
    1 => '1 day'
  }.freeze

  def perform
    Rails.logger.info 'SocialMediaReminderJob: Starting social media reminder job'

    site_config = SiteConfig.current
    unless site_config.social_reminders_enabled?
      Rails.logger.info 'SocialMediaReminderJob: Social reminders disabled in site config, exiting'
      return
    end

    REMINDER_OFFSETS.each do |days_ahead, label|
      post_reminders_for_days(days_ahead, label)
    end

    Rails.logger.info 'SocialMediaReminderJob: Completed'
  end

  private

  def post_reminders_for_days(days_ahead, label)
    target_date = Date.current + days_ahead.days
    start_time = target_date.beginning_of_day
    end_time = target_date.end_of_day

    Rails.logger.info "SocialMediaReminderJob: Looking for occurrences on #{target_date} (#{label} reminder)"

    occurrences = EventOccurrence
                  .joins(:event)
                  .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?', start_time, end_time)
                  .where(event_occurrences: { status: %w[active cancelled postponed relocated] })
                  .where(events: { status: 'active', draft: false, social_reminders: true })
                  .where(events: { visibility: %w[public members] })
                  .includes(:event)

    Rails.logger.info "SocialMediaReminderJob: Found #{occurrences.count} occurrences for #{target_date}"

    if occurrences.empty?
      Rails.logger.info "SocialMediaReminderJob: No occurrences to post for #{target_date}"
      return
    end

    occurrences.each do |occurrence|
      Rails.logger.info "SocialMediaReminderJob: Processing '#{occurrence.event.title}' " \
                        "(occurrence ##{occurrence.id}, status: #{occurrence.status})"

      # Check if already posted today for this occurrence and label
      if already_posted_today?(occurrence, label)
        Rails.logger.info "SocialMediaReminderJob: Skipping '#{occurrence.event.title}' - " \
                          "already posted #{label} reminder today"
        next
      end

      short_parts = reminder_message_with_link(occurrence, label, days_ahead: days_ahead, message_type: :short)
      long_parts = reminder_message_with_link(occurrence, label, days_ahead: days_ahead, message_type: :long)

      Rails.logger.info "SocialMediaReminderJob: Posting reminder for '#{occurrence.event.title}'"
      SocialService.post_occurrence_reminder(occurrence, short_parts: short_parts, long_parts: long_parts)

      # Small delay between posts to avoid rate limiting
      sleep(5) if occurrences.many?
    end
  end

  def already_posted_today?(occurrence, label)
    # Check if we've already posted a social media reminder for this occurrence today
    # This prevents duplicate posts if the job runs multiple times
    ReminderPosting.where(
      event_occurrence: occurrence,
      platform: %w[bluesky instagram]
    ).exists?(
      ['posted_at >= ? AND message LIKE ?', Time.current.beginning_of_day, "%#{label}%"]
    )
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
    event_url = "#{protocol}://#{host}/events/#{event.slug}"
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
