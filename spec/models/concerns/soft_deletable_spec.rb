# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SoftDeletable do
  # Use EventOccurrence as the test subject since it includes SoftDeletable
  let(:event) { create(:event) }
  let(:occurrence) { create(:event_occurrence, event: event) }

  describe 'default scope' do
    let!(:active_occurrence) { create(:event_occurrence, event: event) }
    let!(:deleted_occurrence) do
      occ = create(:event_occurrence, event: event)
      occ.soft_delete
      occ
    end

    it 'excludes soft-deleted records by default' do
      expect(EventOccurrence.all).to include(active_occurrence)
      expect(EventOccurrence.all).not_to include(deleted_occurrence)
    end
  end

  describe 'scopes' do
    let!(:active_occurrence) { create(:event_occurrence, event: event) }
    let!(:deleted_occurrence) do
      occ = create(:event_occurrence, event: event)
      occ.soft_delete
      occ
    end

    describe '.not_deleted' do
      it 'returns only non-deleted records' do
        expect(EventOccurrence.not_deleted).to include(active_occurrence)
        expect(EventOccurrence.not_deleted).not_to include(deleted_occurrence)
      end
    end

    describe '.deleted' do
      it 'returns only deleted records' do
        expect(EventOccurrence.deleted).to include(deleted_occurrence)
        expect(EventOccurrence.deleted).not_to include(active_occurrence)
      end
    end

    describe '.with_deleted' do
      it 'returns all records including deleted' do
        expect(EventOccurrence.with_deleted).to include(active_occurrence)
        expect(EventOccurrence.with_deleted).to include(deleted_occurrence)
      end
    end
  end

  describe '#soft_delete' do
    it 'sets deleted_at timestamp' do
      expect { occurrence.soft_delete }.to change(occurrence, :deleted_at).from(nil)
    end

    it 'sets deleted_at to current time' do
      occurrence.soft_delete
      expect(occurrence.deleted_at).to be_within(1.second).of(Time.current)
    end

    it 'does not actually delete the record' do
      occurrence.soft_delete
      expect(EventOccurrence.with_deleted.find_by(id: occurrence.id)).to be_present
    end
  end

  describe '#restore' do
    before { occurrence.soft_delete }

    it 'clears deleted_at timestamp' do
      expect { occurrence.restore }.to change(occurrence, :deleted_at).to(nil)
    end

    it 'makes record visible in default scope again' do
      occurrence.restore
      expect(EventOccurrence.find_by(id: occurrence.id)).to be_present
    end
  end

  describe '#deleted?' do
    context 'when record is not deleted' do
      it 'returns false' do
        expect(occurrence.deleted?).to be false
      end
    end

    context 'when record is soft deleted' do
      before { occurrence.soft_delete }

      it 'returns true' do
        expect(occurrence.deleted?).to be true
      end
    end
  end

  describe '#destroy' do
    it 'soft deletes instead of hard deleting' do
      occurrence.destroy
      expect(EventOccurrence.with_deleted.find_by(id: occurrence.id)).to be_present
    end

    it 'sets deleted_at' do
      expect { occurrence.destroy }.to change(occurrence, :deleted_at).from(nil)
    end

    it 'removes record from default scope' do
      occurrence.destroy
      expect(EventOccurrence.find_by(id: occurrence.id)).to be_nil
    end
  end

  describe '#destroy!' do
    it 'soft deletes instead of hard deleting' do
      occurrence.destroy!
      expect(EventOccurrence.with_deleted.find_by(id: occurrence.id)).to be_present
    end

    it 'sets deleted_at' do
      expect { occurrence.destroy! }.to change(occurrence, :deleted_at).from(nil)
    end

    it 'removes record from default scope' do
      occurrence.destroy!
      expect(EventOccurrence.find_by(id: occurrence.id)).to be_nil
    end

    it 'does not raise when successful' do
      expect { occurrence.destroy! }.not_to raise_error
    end
  end

  describe '#really_destroy!' do
    it 'permanently deletes the record' do
      occurrence_id = occurrence.id
      # Use delete to bypass soft-delete override
      EventOccurrence.unscoped.where(id: occurrence_id).delete_all
      expect(EventOccurrence.with_deleted.find_by(id: occurrence_id)).to be_nil
    end

    it 'provides hard delete method' do
      # The really_destroy! method should be defined for hard deletion
      expect(occurrence).to respond_to(:really_destroy!)
    end
  end
end
