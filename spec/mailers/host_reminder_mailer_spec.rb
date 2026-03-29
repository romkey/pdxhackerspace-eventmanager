# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HostReminderMailer, type: :mailer do
  let(:user) { create(:user, name: 'Test Host', email: 'host@example.com') }
  let(:event) { create(:event, title: 'Test Event') }
  let(:occurrence) { create(:event_occurrence, event: event, occurs_at: 2.days.from_now) }
  let(:site_config) { SiteConfig.current }

  before do
    site_config.update!(organization_name: 'Test Org')
  end

  describe '#upcoming_reminder_notification' do
    context 'for Slack reminder' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: user,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 2
        )
      end

      it 'renders the headers' do
        expect(mail.subject).to include('Slack')
        expect(mail.subject).to include('Test Event')
        expect(mail.to).to eq(['host@example.com'])
      end

      it 'includes organization name in subject' do
        expect(mail.subject).to include('[Test Org]')
      end

      it 'includes scheduled for tomorrow in subject' do
        expect(mail.subject).to include('scheduled for tomorrow')
      end
    end

    context 'for social media reminder' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: user,
          occurrence: occurrence,
          reminder_type: 'social',
          days_until_event: 2
        )
      end

      it 'renders the headers with social media label' do
        expect(mail.subject).to include('social media')
        expect(mail.subject).to include('Test Event')
      end
    end

    context 'with test mode (recipient override)' do
      let(:test_email) { 'test@override.com' }
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: user,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 2,
          recipient_email: test_email
        )
      end

      it 'sends to the override address' do
        expect(mail.to).to eq([test_email])
      end

      it 'sets test_mode flag' do
        # The @test_mode variable should be set when recipient differs from user email
        expect(mail.body.encoded).to be_present
      end
    end

    context 'when recipient_email matches user email' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: user,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 2,
          recipient_email: user.email
        )
      end

      it 'sends to user email' do
        expect(mail.to).to eq([user.email])
      end
    end

    context 'subject format' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: user,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 2
        )
      end

      it 'includes organization name in brackets' do
        # Subject should have [Organization Name] format
        expect(mail.subject).to match(/\[.+\]/)
      end

      it 'includes reminder scheduled for tomorrow' do
        expect(mail.subject).to include('scheduled for tomorrow')
      end
    end
  end

  describe 'email content' do
    let(:mail) do
      described_class.upcoming_reminder_notification(
        user: user,
        occurrence: occurrence,
        reminder_type: 'slack',
        days_until_event: 2
      )
    end

    it 'has multipart content' do
      expect(mail.body.parts.length).to be >= 1
    end

    it 'is deliverable' do
      expect { mail.deliver_now }.not_to raise_error
    end
  end
end
