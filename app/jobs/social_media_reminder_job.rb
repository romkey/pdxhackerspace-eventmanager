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

    # Delay between posts to avoid rate limiting (in seconds)
    post_delay = 5
    enqueued_count = 0
    skipped_count = 0

    occurrences.each_with_index do |occurrence, index|
      Rails.logger.info "SocialMediaReminderJob: Processing '#{occurrence.event.title}' " \
                        "(occurrence ##{occurrence.id}, status: #{occurrence.status})"

      # Check if already posted today for this occurrence and label
      if already_posted_today?(occurrence, label)
        Rails.logger.info "SocialMediaReminderJob: Skipping '#{occurrence.event.title}' - " \
                          "already posted #{label} reminder today"
        skipped_count += 1
        next
      end

      # Schedule the reminder with staggered delay to avoid rate limiting
      delay = index * post_delay
      Rails.logger.info "SocialMediaReminderJob: Scheduling reminder for '#{occurrence.event.title}' (#{label}) in #{delay}s"
      SocialPostReminderJob.set(wait: delay.seconds).perform_later(occurrence.id, label, days_ahead)
      enqueued_count += 1
    end

    Rails.logger.info "SocialMediaReminderJob: Completed #{label} - enqueued: #{enqueued_count}, skipped: #{skipped_count}"
  end

  def already_posted_today?(occurrence, label)
    # Check if we've already posted a social media reminder for this occurrence today
    # This prevents duplicate posts if the job runs multiple times
    ReminderPosting.exists?(event_occurrence: occurrence,
                            platform: %w[bluesky instagram],
                            reminder_type: label,
                            posted_at: Time.current.all_day)
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
