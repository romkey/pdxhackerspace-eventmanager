# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HostReminderNotificationJob, type: :job do
  let!(:site_config) do
    create(:site_config, slack_enabled: true, social_reminders_enabled: true, host_email_reminders_enabled: true)
  end
  let(:host) { create(:user, email_reminders_enabled: true) }
  let(:event) do
    create(:event,
           user: host,
           status: 'active',
           draft: false,
           visibility: 'public',
           slack_announce: true,
           social_reminders: true)
  end

  let(:mock_mail) { double('Mail', deliver_later: true) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).with('SLACK_WEBHOOK_URL', nil).and_return('https://hooks.slack.com/test')
    allow(ENV).to receive(:[]).with('SLACK_WEBHOOK_URL').and_return('https://hooks.slack.com/test')
  end

  describe '#perform' do
    context 'when host email reminders are disabled at site level' do
      before do
        site_config.update!(host_email_reminders_enabled: false)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send any notifications' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'when no reminders are enabled' do
      before do
        site_config.update!(slack_enabled: false, social_reminders_enabled: false)
      end

      it 'does not send any notifications' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'with event 8 days away (7-day reminder tomorrow)' do
      before do
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
        allow(HostReminderMailer).to receive(:upcoming_reminder_notification).and_return(mock_mail)
      end

      it 'sends notification to host for Slack reminder' do
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).with(
          hash_including(user: host, reminder_type: 'slack', days_until_event: 8)
        ).and_call_original
        described_class.perform_now
      end

      it 'sends notification to host for social reminder' do
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).with(
          hash_including(user: host, reminder_type: 'social', days_until_event: 8)
        ).and_call_original
        described_class.perform_now
      end

      it 'sends separate notifications for slack and social' do
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).twice.and_return(mock_mail)
        described_class.perform_now
      end
    end

    context 'with event 2 days away (1-day reminder tomorrow)' do
      before do
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 2.days.from_now.beginning_of_day + 14.hours)
        allow(HostReminderMailer).to receive(:upcoming_reminder_notification).and_return(mock_mail)
      end

      it 'sends notification to host' do
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).at_least(:once).and_return(mock_mail)
        described_class.perform_now
      end

      it 'uses correct days_until_event value' do
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).with(
          hash_including(days_until_event: 2)
        ).at_least(:once).and_return(mock_mail)
        described_class.perform_now
      end
    end

    context 'with host who has disabled email reminders' do
      before do
        host.update!(email_reminders_enabled: false)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send notification' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'with multiple hosts' do
      let(:host2) { create(:user, email_reminders_enabled: true) }

      before do
        event.add_host(host2)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
        allow(HostReminderMailer).to receive(:upcoming_reminder_notification).and_return(mock_mail)
      end

      it 'sends notifications to all hosts with email reminders enabled' do
        # 2 hosts * 2 reminder types (slack + social) = 4 calls
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).exactly(4).times.and_return(mock_mail)
        described_class.perform_now
      end
    end

    context 'with one host who has disabled reminders' do
      let(:host2) { create(:user, email_reminders_enabled: false) }

      before do
        event.add_host(host2)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
        allow(HostReminderMailer).to receive(:upcoming_reminder_notification).and_return(mock_mail)
      end

      it 'only sends to hosts with reminders enabled' do
        # Only host (not host2) * 2 reminder types = 2 calls
        expect(HostReminderMailer).to receive(:upcoming_reminder_notification).with(
          hash_including(user: host)
        ).twice.and_return(mock_mail)
        described_class.perform_now
      end
    end

    context 'with private event' do
      before do
        event.update!(visibility: 'private')
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send notification' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'with draft event' do
      before do
        event.update!(draft: true)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send notification' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'with event that has both reminder types disabled' do
      before do
        event.update!(slack_announce: false, social_reminders: false)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send notification' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'with cancelled occurrence' do
      before do
        event.occurrences.destroy_all
        create(:event_occurrence, :cancelled, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send notification' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end

    context 'when slack webhook is not configured' do
      before do
        allow(ENV).to receive(:fetch).with('SLACK_WEBHOOK_URL', nil).and_return(nil)
        allow(ENV).to receive(:[]).with('SLACK_WEBHOOK_URL').and_return(nil)
        site_config.update!(social_reminders_enabled: false)
        event.occurrences.destroy_all
        create(:event_occurrence, event: event, occurs_at: 8.days.from_now.beginning_of_day + 14.hours)
      end

      it 'does not send notification when only slack is enabled but not configured' do
        expect(HostReminderMailer).not_to receive(:upcoming_reminder_notification)
        described_class.perform_now
      end
    end
  end

  describe 'job configuration' do
    it 'is enqueued in the mailers queue' do
      expect(described_class.new.queue_name).to eq('mailers')
    end
  end
end
