# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HostReminderMailer, type: :mailer do
  before { create(:site_config, organization_name: 'Test Hackerspace') }

  let(:host) { create(:user, name: 'Event Host', email: 'host@example.com') }
  let(:event) { create(:event, title: 'Weekly Workshop', user: host) }
  let(:occurrence) { event.occurrences.first || create(:event_occurrence, event: event, occurs_at: 8.days.from_now) }

  describe '#upcoming_reminder_notification' do
    context 'for Slack reminder' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: host,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 8
        )
      end

      it 'renders the subject with event title' do
        expect(mail.subject).to include('Weekly Workshop')
        expect(mail.subject).to include('Slack')
      end

      it 'sends to the correct recipient' do
        expect(mail.to).to eq(['host@example.com'])
      end

      it 'includes the organization name in subject' do
        expect(mail.subject).to include('Test Hackerspace')
      end

      it 'includes the event title in the body' do
        expect(mail.body.encoded).to include('Weekly Workshop')
      end

      it 'includes the host name in the greeting' do
        expect(mail.body.encoded).to include('Event Host')
      end

      it 'mentions Slack in the body' do
        expect(mail.body.encoded).to include('Slack')
      end

      it 'includes link to edit the occurrence' do
        expect(mail.body.encoded).to include(edit_event_occurrence_url(occurrence))
      end

      it 'includes link to notification preferences' do
        expect(mail.body.encoded).to include('notification preferences')
      end
    end

    context 'for social media reminder' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: host,
          occurrence: occurrence,
          reminder_type: 'social',
          days_until_event: 8
        )
      end

      it 'renders the subject with social media' do
        expect(mail.subject).to include('social media')
      end

      it 'mentions social media in the body' do
        expect(mail.body.encoded).to include('social media')
      end

      it 'mentions both short and long message formats' do
        expect(mail.body.encoded).to include('Short Message')
        expect(mail.body.encoded).to include('Long Message')
      end
    end

    context 'with location' do
      let(:location) { create(:location, name: 'Main Workshop') }

      before { event.update!(location: location) }

      it 'includes the location in the body' do
        mail = described_class.upcoming_reminder_notification(
          user: host,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 8
        )
        expect(mail.body.encoded).to include('Main Workshop')
      end
    end

    context 'text version' do
      let(:mail) do
        described_class.upcoming_reminder_notification(
          user: host,
          occurrence: occurrence,
          reminder_type: 'slack',
          days_until_event: 8
        )
      end

      it 'includes event details in plain text' do
        text_part = mail.text_part.body.decoded
        expect(text_part).to include('Weekly Workshop')
        expect(text_part).to include('Event Host')
      end
    end
  end
end
