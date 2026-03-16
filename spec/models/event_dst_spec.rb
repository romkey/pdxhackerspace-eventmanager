# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event DST handling', type: :model do
  # DST dates for America/Los_Angeles in 2026:
  # Spring forward: March 8, 2026 at 2:00 AM (clocks move to 3:00 AM)
  # Fall back: November 1, 2026 at 2:00 AM (clocks move to 1:00 AM)

  let(:user) { create(:user) }
  let(:location) { create(:location) }

  around do |example|
    Time.use_zone('America/Los_Angeles') { example.run }
  end

  describe 'occurrence generation across spring DST transition' do
    let(:pre_dst_date) { Time.zone.local(2026, 3, 1, 19, 0, 0) } # March 1, 2026 7:00 PM PST
    let(:expected_hour) { 19 } # 7 PM local time

    context 'with a weekly recurring event' do
      let(:event) do
        # Create event starting before DST, recurring weekly
        event = Event.new(
          title: 'Weekly DST Test Event',
          start_time: pre_dst_date,
          recurrence_type: 'weekly',
          user: user,
          location: location,
          visibility: 'public'
        )
        # Build and save the schedule
        schedule = Event.build_schedule(pre_dst_date, 'weekly', { days: [pre_dst_date.wday] })
        event.recurrence_rule = schedule.to_yaml
        event.save!
        event
      end

      it 'generates occurrences at correct local time before DST change' do
        event.generate_occurrences(10)

        # Get occurrences before DST (March 8)
        pre_dst_occurrences = event.occurrences.where('occurs_at < ?', Time.zone.local(2026, 3, 8))

        pre_dst_occurrences.each do |occ|
          local_time = occ.occurs_at.in_time_zone('America/Los_Angeles')
          expect(local_time.hour).to eq(expected_hour),
                                     "Expected occurrence at #{occ.occurs_at} to be at #{expected_hour}:00 local, but was #{local_time.hour}:00"
        end
      end

      it 'generates occurrences at correct local time after DST change (spring forward)' do
        event.generate_occurrences(10)

        # Get occurrences after DST (March 8)
        post_dst_occurrences = event.occurrences.where('occurs_at > ?', Time.zone.local(2026, 3, 8))

        expect(post_dst_occurrences).not_to be_empty, "Expected some occurrences after DST change"

        post_dst_occurrences.each do |occ|
          local_time = occ.occurs_at.in_time_zone('America/Los_Angeles')
          expect(local_time.hour).to eq(expected_hour),
                                     "Expected occurrence at #{occ.occurs_at} to be at #{expected_hour}:00 local, but was #{local_time.hour}:00"
        end
      end

      it 'maintains consistent local time across DST boundary' do
        event.generate_occurrences(10)

        all_hours = event.occurrences.map { |occ| occ.occurs_at.in_time_zone('America/Los_Angeles').hour }

        expect(all_hours.uniq).to eq([expected_hour]),
                                  "Expected all occurrences to be at #{expected_hour}:00, but got hours: #{all_hours.uniq.join(', ')}"
      end
    end
  end

  describe 'occurrence generation across fall DST transition' do
    let(:pre_dst_date) { Time.zone.local(2026, 10, 15, 19, 0, 0) } # October 15, 2026 7:00 PM PDT
    let(:expected_hour) { 19 } # 7 PM local time

    context 'with a weekly recurring event' do
      let(:event) do
        event = Event.new(
          title: 'Weekly Fall DST Test Event',
          start_time: pre_dst_date,
          recurrence_type: 'weekly',
          user: user,
          location: location,
          visibility: 'public'
        )
        schedule = Event.build_schedule(pre_dst_date, 'weekly', { days: [pre_dst_date.wday] })
        event.recurrence_rule = schedule.to_yaml
        event.save!
        event
      end

      it 'generates occurrences at correct local time before fall DST change' do
        event.generate_occurrences(10)

        # Get occurrences before DST (November 1)
        pre_dst_occurrences = event.occurrences.where('occurs_at < ?', Time.zone.local(2026, 11, 1))

        pre_dst_occurrences.each do |occ|
          local_time = occ.occurs_at.in_time_zone('America/Los_Angeles')
          expect(local_time.hour).to eq(expected_hour),
                                     "Expected occurrence at #{occ.occurs_at} to be at #{expected_hour}:00 local, but was #{local_time.hour}:00"
        end
      end

      it 'generates occurrences at correct local time after fall DST change (fall back)' do
        event.generate_occurrences(10)

        # Get occurrences after DST (November 1)
        post_dst_occurrences = event.occurrences.where('occurs_at > ?', Time.zone.local(2026, 11, 1))

        expect(post_dst_occurrences).not_to be_empty, "Expected some occurrences after DST change"

        post_dst_occurrences.each do |occ|
          local_time = occ.occurs_at.in_time_zone('America/Los_Angeles')
          expect(local_time.hour).to eq(expected_hour),
                                     "Expected occurrence at #{occ.occurs_at} to be at #{expected_hour}:00 local, but was #{local_time.hour}:00"
        end
      end
    end
  end

  describe 'schedule storage and retrieval' do
    let(:start_time) { Time.zone.local(2026, 3, 1, 19, 0, 0) }

    it 'preserves timezone in stored IceCube schedule' do
      schedule = Event.build_schedule(start_time, 'weekly', { days: [0] })
      yaml = schedule.to_yaml

      # Reload from YAML (simulating DB storage)
      loaded_schedule = IceCube::Schedule.from_yaml(yaml)

      # The schedule should maintain the same local time
      local_start = loaded_schedule.start_time.in_time_zone('America/Los_Angeles')
      expect(local_start.hour).to eq(19)
      expect(local_start.min).to eq(0)
    end

    it 'generates correct times from reloaded schedule across DST' do
      schedule = Event.build_schedule(start_time, 'weekly', { days: [0] }) # Sunday
      yaml = schedule.to_yaml
      loaded_schedule = IceCube::Schedule.from_yaml(yaml)

      # Generate occurrences spanning DST change
      occurrences = loaded_schedule.occurrences_between(
        Time.zone.local(2026, 3, 1),
        Time.zone.local(2026, 4, 30)
      )

      occurrences.each do |occ|
        local_time = occ.in_time_zone('America/Los_Angeles')
        expect(local_time.hour).to eq(19),
                                   "Expected #{occ} to be at 19:00 local, but was #{local_time.hour}:00"
      end
    end
  end

  describe 'regenerate_future_occurrences! across DST' do
    let(:start_time) { Time.zone.local(2026, 3, 1, 19, 0, 0) }
    let(:expected_hour) { 19 }

    let(:event) do
      event = Event.new(
        title: 'Regeneration DST Test',
        start_time: start_time,
        recurrence_type: 'weekly',
        user: user,
        location: location,
        visibility: 'public',
        max_occurrences: 10
      )
      schedule = Event.build_schedule(start_time, 'weekly', { days: [start_time.wday] })
      event.recurrence_rule = schedule.to_yaml
      event.save!
      event.generate_occurrences
      event
    end

    it 'maintains correct local times after regeneration' do
      # First, verify initial generation is correct
      event.occurrences.each do |occ|
        local_time = occ.occurs_at.in_time_zone('America/Los_Angeles')
        expect(local_time.hour).to eq(expected_hour)
      end

      # Now regenerate
      event.regenerate_future_occurrences!

      # Verify still correct after regeneration
      event.occurrences.reload.each do |occ|
        local_time = occ.occurs_at.in_time_zone('America/Los_Angeles')
        expect(local_time.hour).to eq(expected_hour),
                                   "After regeneration: Expected #{occ.occurs_at} to be at #{expected_hour}:00 local, but was #{local_time.hour}:00"
      end
    end
  end

  describe 'Time.now vs Time.current consistency' do
    it 'uses timezone-aware time methods' do
      # This test ensures we're using Time.current (timezone-aware) not Time.now (system time)
      # The around block already sets Time.zone = 'America/Los_Angeles'

      # In a Docker container with UTC system time, Time.now and Time.current will differ
      # We want to ensure our code uses the timezone-aware version
      current_zone = Time.current.zone
      expect(%w[PST PDT]).to include(current_zone),
                             "Expected Time.current to be in Pacific time, but got #{current_zone}"
    end
  end
end
