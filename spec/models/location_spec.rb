require 'rails_helper'

RSpec.describe Location, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:events).dependent(:nullify) }
    it { is_expected.to have_many(:event_occurrences).dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:location) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(500) }
  end

  describe 'scopes' do
    describe '.alphabetical' do
      it 'orders by name' do
        zebra = create(:location, name: 'Zebra')
        alpha = create(:location, name: 'Alpha')
        middle = create(:location, name: 'Middle')

        expect(described_class.alphabetical.to_a).to eq([alpha, middle, zebra])
      end
    end
  end

  describe '.default' do
    it 'returns Main Space location if it exists' do
      main_space = create(:location, name: 'Main Space')
      create(:location, name: 'Other')

      expect(described_class.default).to eq(main_space)
    end

    it 'returns first location if Main Space does not exist' do
      first_loc = create(:location, name: 'Alpha')
      create(:location, name: 'Zebra')

      expect(described_class.default).to eq(first_loc)
    end

    it 'returns nil if no locations exist' do
      expect(described_class.default).to be_nil
    end
  end
end
