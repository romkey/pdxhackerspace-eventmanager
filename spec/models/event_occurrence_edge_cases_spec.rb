# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Occurrence Edge Cases', type: :model do
  describe 'max_occurrences behavior' do
    context 'when max_occurrences is 1' do
      let(:event) { create(:event, :weekly, max_occurrences: 1) }

      it 'creates only one occurrence' do
        expect(event.occurrences.count).to eq(1)
      end

      it 'respects limit when regenerating' do
        event.regenerate_future_occurrences!

        expect(event.occurrences.count).to eq(1)
      end
    end

    context 'when max_occurrences is changed' do
      let(:event) { create(:event, :weekly, max_occurrences: 3) }

      it 'can increase occurrences' do
        initial_count = event.occurrences.count
        event.update!(max_occurrences: 5)
        event.regenerate_future_occurrences!

        expect(event.occurrences.count).to be >= initial_count
      end
    end
  end

  describe 'permanently_cancelled behavior' do
    let(:event) { create(:event, :weekly, max_occurrences: 5) }

    context 'when set mid-series' do
      before do
        event.occurrences.destroy_all
        event.generate_occurrences
      end

      it 'stops generating new occurrences' do
        event.update!(permanently_cancelled: true)
        event.generate_occurrences

        # Should not have generated more
        expect(event.reload.occurrences.count).to eq(event.occurrences.count)
      end
    end

    context 'when toggled back off' do
      it 'allows generation again' do
        event.update!(permanently_cancelled: true)
        event.occurrences.destroy_all

        event.update!(permanently_cancelled: false)
        event.generate_occurrences

        expect(event.occurrences).to be_present
      end
    end
  end

  describe 'default_to_cancelled behavior' do
    context 'when toggled on for existing event' do
      let(:event) { create(:event, :weekly, max_occurrences: 3, default_to_cancelled: false) }

      it 'creates new occurrences as cancelled' do
        event.update!(default_to_cancelled: true)
        event.occurrences.destroy_all
        event.generate_occurrences

        expect(event.occurrences.all? { |o| o.status == 'cancelled' }).to be true
      end
    end

    context 'when toggled off' do
      let(:event) { create(:event, :weekly, max_occurrences: 3, default_to_cancelled: true) }

      it 'does not change existing occurrences' do
        existing_statuses = event.occurrences.pluck(:status)
        event.update!(default_to_cancelled: false)

        expect(event.occurrences.reload.pluck(:status)).to eq(existing_statuses)
      end
    end
  end

  describe 'check_conflicts' do
    context 'for single occurrence event' do
      let(:event) { create(:event, recurrence_type: 'once', start_time: 1.week.from_now) }

      it 'returns array' do
        conflicts = event.check_conflicts

        expect(conflicts).to be_an(Array)
      end

      it 'finds conflicting events' do
        conflicting_event = create(:event, recurrence_type: 'once', start_time: event.start_time)

        conflicts = event.check_conflicts

        expect(conflicts.pluck(:event)).to include(conflicting_event)
      end
    end

    context 'for recurring event' do
      let(:event) { create(:event, :weekly, max_occurrences: 3) }

      it 'checks multiple occurrences' do
        conflicts = event.check_conflicts(5)

        expect(conflicts).to be_an(Array)
      end
    end
  end

  describe 'occurrence date conflicts' do
    let(:event) { create(:event, :weekly, start_time: 1.week.from_now) }

    context 'when occurrence is postponed to same date as another' do
      let!(:first_occurrence) { event.occurrences.first }
      let!(:second_occurrence) { event.occurrences.second }

      it 'allows both occurrences to exist' do
        first_occurrence.update!(
          status: 'postponed',
          postponed_until: second_occurrence.occurs_at
        )

        expect(first_occurrence).to be_valid
        expect(second_occurrence).to be_valid
      end
    end
  end

  describe 'soft delete integration' do
    let(:event) { create(:event, :weekly, max_occurrences: 3) }

    context 'when occurrence is soft deleted' do
      it 'excludes from default scope' do
        occurrence = event.occurrences.first
        occurrence.destroy

        expect(event.occurrences).not_to include(occurrence)
      end

      it 'can be restored' do
        occurrence = event.occurrences.first
        occurrence.destroy
        occurrence.restore

        expect(event.occurrences).to include(occurrence)
      end
    end
  end

  describe 'regeneration preserves modified occurrences' do
    let(:event) { create(:event, :weekly, max_occurrences: 5) }

    it 'keeps cancelled occurrences' do
      occurrence = event.occurrences.second
      occurrence.update!(status: 'cancelled')

      event.regenerate_future_occurrences!

      expect(EventOccurrence.find_by(id: occurrence.id)).to be_present
      expect(occurrence.reload.status).to eq('cancelled')
    end

    it 'keeps postponed occurrences' do
      occurrence = event.occurrences.second
      occurrence.update!(status: 'postponed', postponed_until: 1.month.from_now)

      event.regenerate_future_occurrences!

      expect(EventOccurrence.find_by(id: occurrence.id)).to be_present
    end

    it 'keeps relocated occurrences' do
      occurrence = event.occurrences.second
      occurrence.update!(status: 'relocated', relocated_to: 'New Venue')

      event.regenerate_future_occurrences!

      expect(EventOccurrence.find_by(id: occurrence.id)).to be_present
    end
  end

  describe 'timezone handling' do
    let(:la_zone) { Time.find_zone('America/Los_Angeles') }

    context 'with events spanning DST transitions' do
      let(:event) do
        # Event starts in winter (PST)
        create(:event, :weekly,
               start_time: la_zone.local(2025, 1, 7, 19, 0, 0),
               max_occurrences: 20)
      end

      it 'generates occurrences with consistent wall-clock time' do
        event.occurrences.each do |occ|
          local_hour = occ.occurs_at.in_time_zone(la_zone).hour
          expect(local_hour).to eq(19), "Expected 7 PM but got #{local_hour}:00 for #{occ.occurs_at}"
        end
      end

      it 'uses correct DST offset for each occurrence' do
        event.occurrences.each do |occ|
          local_time = occ.occurs_at.in_time_zone(la_zone)
          expected_offset = local_time.dst? ? (-7 * 3600) : (-8 * 3600)

          expect(local_time.utc_offset).to eq(expected_offset),
                                           "Expected offset #{expected_offset / 3600}h but got #{local_time.utc_offset / 3600}h for #{occ.occurs_at}"
        end
      end
    end
  end
end
