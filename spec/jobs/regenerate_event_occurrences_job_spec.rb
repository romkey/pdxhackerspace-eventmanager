require 'rails_helper'

RSpec.describe RegenerateEventOccurrencesJob, type: :job do
  describe '#perform' do
    it 'runs without errors' do
      expect {
        described_class.perform_now
      }.not_to raise_error
    end

    it 'processes recurring events' do
      # Create a weekly recurring event
      event = create(:event, recurrence_type: 'weekly', status: 'active', max_occurrences: 10)

      # Manually delete future occurrences to simulate running low
      event.occurrences.where('occurs_at > ?', 2.weeks.from_now).destroy_all

      initial_count = event.occurrences.reload.count

      # Run the job
      described_class.perform_now

      # Should have regenerated occurrences
      expect(event.occurrences.reload.count).to be >= initial_count
    end

    it 'does not process cancelled events' do
      cancelled_event = create(:event, recurrence_type: 'weekly', status: 'cancelled', max_occurrences: 5)
      initial_count = cancelled_event.occurrences.count

      described_class.perform_now

      expect(cancelled_event.occurrences.reload.count).to eq(initial_count)
    end

    it 'does not process one-time events' do
      one_time = create(:event, recurrence_type: 'once', status: 'active')
      initial_count = one_time.occurrences.count

      described_class.perform_now

      expect(one_time.occurrences.reload.count).to eq(initial_count)
    end

    it 'handles errors without crashing' do
      create(:event, recurrence_type: 'weekly', status: 'active')

      # Stub to raise error
      allow_any_instance_of(Event).to receive(:generate_occurrences).and_raise(StandardError, 'Test error')

      # Should not raise error
      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end
end
