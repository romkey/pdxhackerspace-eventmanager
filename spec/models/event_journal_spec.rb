require 'rails_helper'

RSpec.describe EventJournal, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:action) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:event).optional }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:occurrence).optional }
  end

  describe 'scopes' do
    let(:event) { create(:event) }
    let!(:old_entry) { create(:event_journal, event: event, created_at: 2.days.ago) }
    let!(:new_entry) { create(:event_journal, event: event, created_at: 1.day.ago) }

    describe '.recent_first' do
      it 'orders entries by created_at descending' do
        entries = described_class.recent_first
        expect(entries.first).to eq(new_entry)
        expect(entries.last).to eq(old_entry)
      end
    end
  end

  describe '.log_event_change' do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let(:changes) { { 'title' => { 'from' => 'Old', 'to' => 'New' } } }

    it 'creates a journal entry' do
      expect do
        described_class.log_event_change(event, user, 'updated', changes)
      end.to change(described_class, :count).by(1)
    end

    it 'sets the correct attributes' do
      journal = described_class.log_event_change(event, user, 'updated', changes)

      expect(journal.event).to eq(event)
      expect(journal.user).to eq(user)
      expect(journal.action).to eq('updated')
      expect(journal.change_data).to eq(changes)
      expect(journal.occurrence_id).to be_nil
    end
  end

  describe '.log_occurrence_change' do
    let(:occurrence) { create(:event_occurrence) }
    let(:user) { create(:user) }
    let(:changes) { { 'status' => 'cancelled' } }

    it 'creates a journal entry' do
      expect do
        described_class.log_occurrence_change(occurrence, user, 'cancelled', changes)
      end.to change(described_class, :count).by(1)
    end

    it 'sets the correct attributes' do
      journal = described_class.log_occurrence_change(occurrence, user, 'cancelled', changes)

      expect(journal.event).to eq(occurrence.event)
      expect(journal.user).to eq(user)
      expect(journal.action).to eq('cancelled')
      expect(journal.change_data).to eq(changes)
      expect(journal.occurrence_id).to eq(occurrence.id)
    end
  end

  describe '#summary' do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    context 'for event creation' do
      let(:journal) { create(:event_journal, :created, event: event, user: user) }

      it 'returns appropriate message' do
        expect(journal.summary).to eq('Created event')
      end
    end

    context 'for event update' do
      let(:journal) { create(:event_journal, event: event, user: user, action: 'updated', change_data: { 'title' => {} }) }

      it 'includes changed fields' do
        expect(journal.summary).to include('Updated event')
        expect(journal.summary).to include('title')
      end
    end

    context 'for event cancellation' do
      let(:journal) { create(:event_journal, :cancelled, event: event, user: user) }

      it 'returns appropriate message' do
        expect(journal.summary).to eq('Cancelled event')
      end
    end

    context 'for event postponement' do
      let(:journal) { create(:event_journal, :postponed, event: event, user: user) }

      it 'returns appropriate message' do
        expect(journal.summary).to eq('Postponed event')
      end
    end

    context 'for event reactivation' do
      let(:journal) { create(:event_journal, event: event, user: user, action: 'reactivated') }

      it 'returns appropriate message' do
        expect(journal.summary).to eq('Reactivated event')
      end
    end

    context 'for host addition' do
      let(:journal) { create(:event_journal, :host_added, event: event, user: user) }

      it 'includes added host email' do
        expect(journal.summary).to include('Added')
        expect(journal.summary).to include('user@example.com')
        expect(journal.summary).to include('co-host')
      end
    end

    context 'for host removal' do
      let(:journal) { create(:event_journal, event: event, user: user, action: 'host_removed', change_data: { 'removed_host' => 'test@example.com' }) }

      it 'includes removed host email' do
        expect(journal.summary).to include('Removed')
        expect(journal.summary).to include('test@example.com')
        expect(journal.summary).to include('co-host')
      end
    end

    context 'for banner addition' do
      let(:journal) { create(:event_journal, :banner_added, event: event, user: user) }

      it 'includes banner details' do
        expect(journal.summary).to include('Added banner image')
        expect(journal.summary).to include('test.jpg')
      end
    end

    context 'for banner removal' do
      let(:journal) { create(:event_journal, event: event, user: user, action: 'banner_removed', change_data: { 'banner_image' => { 'action' => 'removed' } }) }

      it 'returns appropriate message' do
        expect(journal.summary).to eq('Removed banner image')
      end
    end

    context 'for occurrence changes' do
      let(:occurrence) { create(:event_occurrence, event: event) }
      let(:journal) { create(:event_journal, :for_occurrence, event: event, user: user, occurrence: occurrence) }

      it 'includes occurrence identifier' do
        expect(journal.summary).to include('occurrence')
      end
    end
  end

  describe '#formatted_changes' do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let(:change_data) { { 'title' => { 'from' => 'Old', 'to' => 'New' }, 'duration' => { 'from' => 60, 'to' => 90 } } }
    let(:journal) { create(:event_journal, event: event, user: user, change_data: change_data) }

    it 'titleizes change keys' do
      formatted = journal.formatted_changes
      expect(formatted.keys).to include('Title', 'Duration')
      expect(formatted.keys).not_to include('title', 'duration')
    end

    it 'returns empty hash when no changes' do
      journal.change_data = {}
      expect(journal.formatted_changes).to eq({})
    end

    it 'returns empty hash when change_data is nil' do
      journal.change_data = nil
      expect(journal.formatted_changes).to eq({})
    end
  end

  describe 'factory' do
    it 'creates a valid journal entry' do
      journal = build(:event_journal)
      expect(journal).to be_valid
    end

    it 'creates a valid journal for occurrence' do
      journal = build(:event_journal, :for_occurrence)
      expect(journal).to be_valid
      expect(journal.occurrence).to be_present
    end

    it 'creates a valid created journal' do
      journal = build(:event_journal, :created)
      expect(journal).to be_valid
      expect(journal.action).to eq('created')
    end

    it 'creates a valid host_added journal' do
      journal = build(:event_journal, :host_added)
      expect(journal).to be_valid
      expect(journal.action).to eq('host_added')
    end
  end
end
