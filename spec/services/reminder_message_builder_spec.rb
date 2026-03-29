# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReminderMessageBuilder do
  # Create a test class that includes the module
  let(:builder_class) { Class.new { include ReminderMessageBuilder } }
  let(:builder) { builder_class.new }
  let(:event) { create(:event, title: 'Test Event', description: 'Event description') }
  let(:location) { create(:location, name: 'Main Hall') }
  let(:occurrence) { create(:event_occurrence, event: event, occurs_at: 1.week.from_now, location: location) }

  describe '#reminder_message_with_link' do
    context 'for active occurrence' do
      it 'returns hash with text, link_url, and link_text' do
        result = builder.reminder_message_with_link(occurrence, '1 week')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:text)
        expect(result).to have_key(:link_url)
        expect(result).to have_key(:link_text)
      end

      it 'includes event title in text' do
        result = builder.reminder_message_with_link(occurrence, '1 week')

        expect(result[:text]).to include(event.title)
      end

      it 'includes occurrence URL' do
        result = builder.reminder_message_with_link(occurrence, '1 week')

        expect(result[:link_url]).to include(occurrence.slug)
      end
    end

    context 'for cancelled occurrence' do
      let(:cancelled_occurrence) do
        create(:event_occurrence, event: event, status: 'cancelled',
                                  cancellation_reason: 'Weather conditions')
      end

      it 'returns cancelled message' do
        result = builder.reminder_message_with_link(cancelled_occurrence, '1 week')

        expect(result[:text]).to include('CANCELLED')
        expect(result[:text]).to include(event.title)
      end

      it 'includes cancellation reason in long format' do
        result = builder.reminder_message_with_link(cancelled_occurrence, '1 week', message_type: :long)

        expect(result[:text]).to include('Weather conditions')
      end
    end

    context 'for postponed occurrence' do
      let(:postponed_occurrence) do
        create(:event_occurrence, event: event, status: 'postponed',
                                  postponed_until: 2.weeks.from_now)
      end

      it 'returns postponed message' do
        result = builder.reminder_message_with_link(postponed_occurrence, '1 week')

        expect(result[:text]).to include('POSTPONED')
        expect(result[:text]).to include(event.title)
      end

      it 'includes new date in message' do
        result = builder.reminder_message_with_link(postponed_occurrence, '1 week')

        expect(result[:text]).to include(postponed_occurrence.postponed_until.strftime('%B %d'))
      end
    end

    context 'for relocated occurrence' do
      let(:relocated_occurrence) do
        create(:event_occurrence, event: event, status: 'relocated',
                                  relocated_to: 'New Venue Downtown')
      end

      it 'returns relocated message' do
        result = builder.reminder_message_with_link(relocated_occurrence, '1 week')

        expect(result[:text]).to include('RELOCATED')
        expect(result[:text]).to include(event.title)
      end

      it 'includes new location' do
        result = builder.reminder_message_with_link(relocated_occurrence, '1 week')

        expect(result[:text]).to include('New Venue Downtown')
      end
    end
  end

  describe '#short_reminder_message' do
    it 'returns combined text and URL' do
      result = builder.short_reminder_message(occurrence, '1 week')

      expect(result).to be_a(String)
      expect(result).to include(event.title)
      expect(result).to include(occurrence.slug)
    end

    it 'generates shorter message than long version' do
      short = builder.short_reminder_message(occurrence, '1 week')
      long = builder.long_reminder_message(occurrence, '1 week')

      expect(short.length).to be < long.length
    end
  end

  describe '#long_reminder_message' do
    it 'returns combined text and URL' do
      result = builder.long_reminder_message(occurrence, '1 week')

      expect(result).to be_a(String)
      expect(result).to include(event.title)
      expect(result).to include(occurrence.slug)
    end

    it 'includes emojis' do
      result = builder.long_reminder_message(occurrence, '1 week')

      expect(result).to include('📅')
      expect(result).to include('🕐')
    end

    it 'includes location when present' do
      result = builder.long_reminder_message(occurrence, '1 week')

      expect(result).to include('Main Hall')
    end

    it 'includes event description' do
      result = builder.long_reminder_message(occurrence, '1 week')

      expect(result).to include('Event description')
    end

    it 'truncates long descriptions' do
      event.update!(description: 'A' * 500)
      result = builder.long_reminder_message(occurrence, '1 week')

      expect(result).to include('...')
      expect(result.length).to be < 600
    end
  end

  describe '#format_timing_phrase' do
    it 'returns "today" unchanged' do
      result = builder.send(:format_timing_phrase, 'today')
      expect(result).to eq('today')
    end

    it 'returns "tomorrow" unchanged' do
      result = builder.send(:format_timing_phrase, 'tomorrow')
      expect(result).to eq('tomorrow')
    end

    it 'adds "in" prefix to "1 day"' do
      result = builder.send(:format_timing_phrase, '1 day')
      expect(result).to eq('in 1 day')
    end

    it 'adds "in" prefix to "1 week"' do
      result = builder.send(:format_timing_phrase, '1 week')
      expect(result).to eq('in 1 week')
    end

    it 'adds "in" prefix to "6 days"' do
      result = builder.send(:format_timing_phrase, '6 days')
      expect(result).to eq('in 6 days')
    end
  end

  describe '#format_duration' do
    it 'formats hours only' do
      result = builder.send(:format_duration, 120)
      expect(result).to eq('2h')
    end

    it 'formats minutes only' do
      result = builder.send(:format_duration, 45)
      expect(result).to eq('45m')
    end

    it 'formats hours and minutes' do
      result = builder.send(:format_duration, 90)
      expect(result).to eq('1h 30m')
    end
  end

  describe '#occurrence_url_for' do
    it 'builds URL with occurrence slug' do
      result = builder.send(:occurrence_url_for, occurrence)

      expect(result).to include(occurrence.slug)
      expect(result).to match(%r{https?://})
    end

    it 'includes host in URL' do
      result = builder.send(:occurrence_url_for, occurrence)

      expect(result).to include('//')
      expect(result).to include('/occurrences/')
    end
  end

  describe 'custom reminder messages' do
    context 'when occurrence has custom short message' do
      let(:occurrence_with_custom) do
        create(:event_occurrence, event: event,
                                  reminder_7d_short: 'Custom 7-day short',
                                  reminder_1d_short: 'Custom 1-day short')
      end

      it 'uses custom 7-day message for advance notices' do
        result = builder.reminder_message_with_link(occurrence_with_custom, '6 days',
                                                    days_ahead: 6, message_type: :short)
        expect(result[:text]).to eq('Custom 7-day short')
      end

      it 'uses custom 1-day message for day-before notices' do
        result = builder.reminder_message_with_link(occurrence_with_custom, '1 day',
                                                    days_ahead: 1, message_type: :short)
        expect(result[:text]).to eq('Custom 1-day short')
      end
    end

    context 'when occurrence has custom long message' do
      let(:occurrence_with_custom) do
        create(:event_occurrence, event: event,
                                  reminder_7d_long: 'Custom 7-day long',
                                  reminder_1d_long: 'Custom 1-day long')
      end

      it 'uses custom 7-day message for advance notices' do
        result = builder.reminder_message_with_link(occurrence_with_custom, '6 days',
                                                    days_ahead: 6, message_type: :long)
        expect(result[:text]).to eq('Custom 7-day long')
      end

      it 'uses custom 1-day message for day-before notices' do
        result = builder.reminder_message_with_link(occurrence_with_custom, '1 day',
                                                    days_ahead: 1, message_type: :long)
        expect(result[:text]).to eq('Custom 1-day long')
      end
    end

    context 'when occurrence inherits from event' do
      let(:event_with_custom) do
        create(:event, reminder_7d_short: 'Event 7-day short')
      end
      let(:occurrence_inheriting) do
        create(:event_occurrence, event: event_with_custom)
      end

      it 'falls back to event reminder when occurrence has none' do
        result = builder.reminder_message_with_link(occurrence_inheriting, '6 days',
                                                    days_ahead: 6, message_type: :short)
        expect(result[:text]).to eq('Event 7-day short')
      end
    end
  end

  describe 'days_ahead inference from label' do
    it 'infers 1 day from "1 day" label' do
      result = builder.reminder_message_with_link(occurrence, '1 day', message_type: :short)
      # Should use 1-day custom message if set
      expect(result[:text]).to be_present
    end

    it 'infers 6 days from "6 days" label' do
      result = builder.reminder_message_with_link(occurrence, '6 days', message_type: :short)
      # Should use 7-day custom message if set
      expect(result[:text]).to be_present
    end
  end
end
