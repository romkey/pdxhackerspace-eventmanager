class SlackEventReminderJob < ApplicationJob
  include ReminderMessageBuilder

  queue_as :default

  REMINDER_OFFSETS = {
    6 => '6 days',
    1 => '1 day'
  }.freeze

  # Delay between posts to prevent Slack from merging/rate limiting
  POST_DELAY_SECONDS = 10

  def perform
    site_config = SiteConfig.current
    unless site_config.slack_enabled?
      Rails.logger.info 'SlackEventReminderJob: Slack not enabled, skipping'
      return
    end

    webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
    if webhook_url.blank?
      Rails.logger.info 'SlackEventReminderJob: No webhook URL configured, skipping'
      return
    end

    Rails.logger.info 'SlackEventReminderJob: Starting reminder run'

    REMINDER_OFFSETS.each do |days_ahead, label|
      post_reminders_for_days(days_ahead, label)
    end

    Rails.logger.info 'SlackEventReminderJob: Completed reminder run'
  end

  private

  def post_reminders_for_days(days_ahead, label)
    target_date = Date.current + days_ahead.days
    start_time = target_date.beginning_of_day
    end_time = target_date.end_of_day

    Rails.logger.info "SlackEventReminderJob: Looking for occurrences on #{target_date} (#{label})"
    Rails.logger.info "SlackEventReminderJob: Query range: #{start_time} to #{end_time}"

    occurrences = EventOccurrence
                  .joins(:event)
                  .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?',
                         start_time, end_time)
                  .where(event_occurrences: { status: %w[active cancelled postponed relocated] })
                  .where(events: { status: 'active', draft: false })
                  .where(events: { visibility: %w[public members] })
                  .where(events: { slack_announce: true })
                  .includes(:event)
                  .order('event_occurrences.occurs_at ASC')

    Rails.logger.info "SlackEventReminderJob: Found #{occurrences.count} occurrences for #{label}"

    if occurrences.empty?
      Rails.logger.info "SlackEventReminderJob: No occurrences to post for #{label}"
      return
    end

    # Log all occurrences we're going to process
    occurrences.each_with_index do |occ, idx|
      Rails.logger.info "SlackEventReminderJob: [#{idx + 1}/#{occurrences.count}] #{occ.event.title} at #{occ.occurs_at} (status: #{occ.status})"
    end

    enqueued_count = 0
    skipped_count = 0

    occurrences.each_with_index do |occurrence, index|
      # Check if already posted today for this occurrence
      if already_posted_today?(occurrence, label)
        Rails.logger.info "SlackEventReminderJob: Skipping '#{occurrence.event.title}' - already posted #{label} reminder today"
        skipped_count += 1
        next
      end

      # Schedule the reminder with staggered delay to avoid rate limiting
      delay = index * POST_DELAY_SECONDS
      Rails.logger.info "SlackEventReminderJob: Scheduling reminder for '#{occurrence.event.title}' (#{label}) in #{delay}s"
      SlackPostReminderJob.set(wait: delay.seconds).perform_later(occurrence.id, label, days_ahead)
      enqueued_count += 1
    end

    Rails.logger.info "SlackEventReminderJob: Completed #{label} - enqueued: #{enqueued_count}, skipped: #{skipped_count}"
  end

  def already_posted_today?(occurrence, label)
    # Check if we've already posted a Slack reminder for this occurrence today
    # This prevents duplicate posts if the job runs multiple times
    ReminderPosting.exists?(event_occurrence: occurrence,
                            platform: 'slack',
                            reminder_type: label,
                            posted_at: Time.current.all_day)
  end
end
