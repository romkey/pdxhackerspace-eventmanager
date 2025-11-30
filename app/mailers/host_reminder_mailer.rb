# frozen_string_literal: true

class HostReminderMailer < ApplicationMailer
  # Notify host that a reminder will be sent tomorrow
  # @param user [User] The event host to notify
  # @param occurrence [EventOccurrence] The occurrence that will be reminded about
  # @param reminder_type [String] "slack" or "social"
  # @param days_until_event [Integer] Days until the event occurs
  def upcoming_reminder_notification(user:, occurrence:, reminder_type:, days_until_event:)
    @user = user
    @occurrence = occurrence
    @event = occurrence.event
    @reminder_type = reminder_type
    @days_until_event = days_until_event
    @site_config = SiteConfig.current

    subject = build_subject
    mail(to: @user.email, subject: subject)
  end

  private

  def build_subject
    reminder_label = @reminder_type == 'slack' ? 'Slack' : 'social media'
    "[#{@site_config&.organization_name || 'EventManager'}] " \
      "Reminder: #{@event.title} #{reminder_label} post scheduled for tomorrow"
  end
end
