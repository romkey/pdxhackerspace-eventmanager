require 'rails_helper'

RSpec.describe EventHost, type: :model do
  describe 'validations' do
    subject { build(:event_host) }
    
    it 'validates uniqueness of user_id scoped to event_id' do
      event = create(:event)
      user = create(:user)
      create(:event_host, event: event, user: user)
      
      duplicate = build(:event_host, event: event, user: user)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:event) }
    it { should belong_to(:user) }
  end

  describe 'unique host constraint' do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    it 'prevents duplicate host assignments' do
      create(:event_host, event: event, user: user)
      duplicate = build(:event_host, event: event, user: user)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('is already a host for this event')
    end

    it 'allows same user to host different events' do
      event2 = create(:event)
      create(:event_host, event: event, user: user)
      host2 = build(:event_host, event: event2, user: user)
      
      expect(host2).to be_valid
    end

    it 'allows different users to host same event' do
      user2 = create(:user)
      create(:event_host, event: event, user: user)
      host2 = build(:event_host, event: event, user: user2)
      
      expect(host2).to be_valid
    end
  end

  describe 'factory' do
    it 'creates a valid event host' do
      event_host = build(:event_host)
      expect(event_host).to be_valid
    end
  end
end

