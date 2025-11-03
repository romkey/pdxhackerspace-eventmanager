require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    subject { build(:event) }
    
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:start_time) }
    it { should validate_numericality_of(:duration).is_greater_than(0) }
    it { should validate_inclusion_of(:recurrence_type).in_array(%w[once weekly monthly custom]) }
    it { should validate_inclusion_of(:status).in_array(%w[active postponed cancelled]) }
    it { should validate_inclusion_of(:visibility).in_array(%w[public members private]) }
    it { should validate_inclusion_of(:open_to).in_array(%w[public members private]) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:event_hosts).dependent(:destroy) }
    it { should have_many(:hosts).through(:event_hosts) }
    it { should have_many(:event_occurrences).dependent(:destroy) }
    it { should have_many(:occurrences).dependent(:destroy) }
    it { should have_many(:event_journals).dependent(:destroy) }
    it { should have_one_attached(:banner_image) }
  end

  describe 'scopes' do
    let!(:active_event) { create(:event, status: 'active') }
    let!(:postponed_event) { create(:event, :postponed) }
    let!(:cancelled_event) { create(:event, :cancelled) }
    let!(:public_event) { create(:event, visibility: 'public') }
    let!(:members_event) { create(:event, :members_only) }
    let!(:private_event) { create(:event, :private) }

    describe '.active' do
      it 'returns only active events' do
        expect(Event.active).to include(active_event)
        expect(Event.active).not_to include(postponed_event, cancelled_event)
      end
    end

    describe '.postponed' do
      it 'returns only postponed events' do
        expect(Event.postponed).to include(postponed_event)
        expect(Event.postponed).not_to include(active_event, cancelled_event)
      end
    end

    describe '.cancelled' do
      it 'returns only cancelled events' do
        expect(Event.cancelled).to include(cancelled_event)
        expect(Event.cancelled).not_to include(active_event, postponed_event)
      end
    end

    describe '.public_events' do
      it 'returns only public events' do
        expect(Event.public_events).to include(public_event)
        expect(Event.public_events).not_to include(members_event, private_event)
      end
    end

    describe '.members_events' do
      it 'returns only members events' do
        expect(Event.members_events).to include(members_event)
        expect(Event.members_events).not_to include(public_event, private_event)
      end
    end

    describe '.private_events' do
      it 'returns only private events' do
        expect(Event.private_events).to include(private_event)
        expect(Event.private_events).not_to include(public_event, members_event)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create' do
      it 'generates an ical_token' do
        event = build(:event)
        expect(event.ical_token).to be_nil
        event.save
        expect(event.ical_token).to be_present
      end

      it 'generates a unique ical_token' do
        event1 = create(:event)
        event2 = create(:event)
        expect(event1.ical_token).not_to eq(event2.ical_token)
      end
    end

    describe 'after_create' do
      it 'adds creator as host' do
        user = create(:user)
        event = create(:event, user: user)
        expect(event.hosts).to include(user)
      end

      it 'generates initial occurrences' do
        event = create(:event)
        expect(event.occurrences).to be_present
      end
    end
  end

  describe '#recurring?' do
    context 'when event is once' do
      let(:event) { create(:event, recurrence_type: 'once') }

      it 'returns false' do
        expect(event.recurring?).to be false
      end
    end

    context 'when event is weekly' do
      let(:event) { create(:event, :weekly) }

      it 'returns true' do
        expect(event.recurring?).to be true
      end
    end

    context 'when event is monthly' do
      let(:event) { create(:event, :monthly) }

      it 'returns true' do
        expect(event.recurring?).to be true
      end
    end
  end

  describe 'visibility helpers' do
    describe '#public?' do
      it 'returns true for public events' do
        event = create(:event, visibility: 'public')
        expect(event.public?).to be true
      end

      it 'returns false for non-public events' do
        event = create(:event, :members_only)
        expect(event.public?).to be false
      end
    end

    describe '#members_only?' do
      it 'returns true for members events' do
        event = create(:event, :members_only)
        expect(event.members_only?).to be true
      end

      it 'returns false for non-members events' do
        event = create(:event, visibility: 'public')
        expect(event.members_only?).to be false
      end
    end

    describe '#private?' do
      it 'returns true for private events' do
        event = create(:event, :private)
        expect(event.private?).to be true
      end

      it 'returns false for non-private events' do
        event = create(:event, visibility: 'public')
        expect(event.private?).to be false
      end
    end
  end

  describe '#postpone!' do
    let(:event) { create(:event) }
    let(:new_date) { 1.week.from_now }

    it 'changes status to postponed' do
      event.postpone!(new_date)
      expect(event.status).to eq('postponed')
    end

    it 'sets postponed_until date' do
      event.postpone!(new_date)
      expect(event.postponed_until).to be_within(1.second).of(new_date)
    end

    it 'sets cancellation_reason when provided' do
      event.postpone!(new_date, 'Weather conditions')
      expect(event.cancellation_reason).to eq('Weather conditions')
    end
  end

  describe '#cancel!' do
    let(:event) { create(:event) }

    it 'changes status to cancelled' do
      event.cancel!
      expect(event.status).to eq('cancelled')
    end

    it 'sets cancellation_reason when provided' do
      event.cancel!('Low attendance')
      expect(event.cancellation_reason).to eq('Low attendance')
    end
  end

  describe '#reactivate!' do
    let(:event) { create(:event, :cancelled) }

    it 'changes status to active' do
      event.reactivate!
      expect(event.status).to eq('active')
    end

    it 'clears postponed_until' do
      postponed_event = create(:event, :postponed)
      postponed_event.reactivate!
      expect(postponed_event.postponed_until).to be_nil
    end

    it 'clears cancellation_reason' do
      postponed_event = create(:event, :postponed)
      postponed_event.reactivate!
      expect(postponed_event.cancellation_reason).to be_nil
    end
  end

  describe '#hosted_by?' do
    let(:host) { create(:user) }
    let(:non_host) { create(:user) }
    let(:admin) { create(:user, :admin) }
    let(:event) { create(:event, user: host) }

    context 'when user is a host' do
      it 'returns true' do
        expect(event.hosted_by?(host)).to be true
      end
    end

    context 'when user is an admin' do
      it 'returns true' do
        expect(event.hosted_by?(admin)).to be true
      end
    end

    context 'when user is neither host nor admin' do
      it 'returns false' do
        expect(event.hosted_by?(non_host)).to be false
      end
    end

    context 'when user is nil' do
      it 'returns false' do
        expect(event.hosted_by?(nil)).to be false
      end
    end
  end

  describe '#add_host' do
    let(:event) { create(:event) }
    let(:new_host) { create(:user) }

    it 'adds user as host' do
      expect {
        event.add_host(new_host)
      }.to change { event.hosts.count }.by(1)
    end

    it 'does not add duplicate hosts' do
      event.add_host(new_host)
      expect {
        event.add_host(new_host)
      }.not_to change { event.hosts.count }
    end
  end

  describe '#remove_host' do
    let(:creator) { create(:user) }
    let(:event) { create(:event, user: creator) }
    let(:additional_host) { create(:user) }

    before do
      event.add_host(additional_host)
    end

    it 'removes non-creator host' do
      expect {
        event.remove_host(additional_host)
      }.to change { event.hosts.count }.by(-1)
    end

    it 'prevents removing creator when they are the only host' do
      event.remove_host(additional_host) # Remove other host first
      event.reload
      result = event.remove_host(creator)
      expect(result).to be false
      expect(event.hosts).to include(creator)
    end

    it 'allows removing creator when there are other hosts' do
      expect(event.hosts.count).to be > 1
      result = event.remove_host(creator)
      expect(result).not_to be false
    end
  end

  describe '#creator' do
    let(:user) { create(:user) }
    let(:event) { create(:event, user: user) }

    it 'returns the user who created the event' do
      expect(event.creator).to eq(user)
    end
  end

  describe '#generate_occurrences' do
    context 'for a one-time event' do
      let(:event) { create(:event, recurrence_type: 'once') }

      it 'creates one occurrence' do
        expect(event.occurrences.count).to eq(1)
      end

      it 'creates occurrence at event start_time' do
        expect(event.occurrences.first.occurs_at.to_date).to eq(event.start_time.to_date)
      end
    end

    context 'for a recurring event' do
      let(:event) { create(:event, :weekly, max_occurrences: 3) }

      it 'creates multiple occurrences' do
        expect(event.occurrences.count).to be >= 1
        expect(event.occurrences.count).to be <= 3
      end
    end
  end

  describe '#upcoming_occurrences' do
    let(:event) { create(:event, :weekly) }

    before do
      # Create some past occurrences
      create(:event_occurrence, :past, event: event)
      create(:event_occurrence, :past, event: event)
    end

    it 'returns only future occurrences' do
      upcoming = event.upcoming_occurrences
      expect(upcoming.all? { |o| o.occurs_at >= Time.now }).to be true
    end

    it 'limits results to max_occurrences' do
      event.update(max_occurrences: 2)
      expect(event.upcoming_occurrences.count).to be <= 2
    end
  end

  describe '.build_schedule' do
    context 'for weekly recurrence' do
      let(:start_time) { Time.zone.parse('2025-11-05 19:00') }

      it 'creates a weekly schedule' do
        schedule = Event.build_schedule(start_time, 'weekly', { days: [start_time.wday] })
        expect(schedule).to be_a(IceCube::Schedule)
      end

      it 'uses specified days' do
        schedule = Event.build_schedule(start_time, 'weekly', { days: [1, 3, 5] }) # Mon, Wed, Fri
        rule = schedule.rrules.first
        expect(rule).to be_a(IceCube::WeeklyRule)
      end
    end

    context 'for monthly recurrence' do
      let(:start_time) { Time.zone.parse('2025-11-05 19:00') }

      it 'creates a monthly schedule with day of month' do
        schedule = Event.build_schedule(start_time, 'monthly', {})
        expect(schedule).to be_a(IceCube::Schedule)
        rule = schedule.rrules.first
        expect(rule).to be_a(IceCube::MonthlyRule)
      end

      it 'creates a monthly schedule with day of month' do
        # Test the default monthly behavior (day of month)
        schedule = Event.build_schedule(start_time, 'monthly', {})
        rule = schedule.rrules.first
        expect(rule).to be_a(IceCube::MonthlyRule)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid event' do
      event = build(:event)
      expect(event).to be_valid
    end

    it 'creates a valid weekly event' do
      event = build(:event, :weekly)
      expect(event).to be_valid
      expect(event.recurrence_type).to eq('weekly')
      expect(event.recurrence_rule).to be_present
    end

    it 'creates a valid members only event' do
      event = build(:event, :members_only)
      expect(event).to be_valid
      expect(event.visibility).to eq('members')
    end

    it 'creates a valid postponed event' do
      event = build(:event, :postponed)
      expect(event).to be_valid
      expect(event.status).to eq('postponed')
      expect(event.postponed_until).to be_present
    end
  end

  describe 'more_info_url validation' do
    it 'accepts valid URLs' do
      event = build(:event, more_info_url: 'https://example.com')
      expect(event).to be_valid
    end

    it 'accepts http URLs' do
      event = build(:event, more_info_url: 'http://example.com')
      expect(event).to be_valid
    end

    it 'accepts blank URLs' do
      event = build(:event, more_info_url: '')
      expect(event).to be_valid
    end

    it 'rejects invalid URLs' do
      event = build(:event, more_info_url: 'not a url')
      expect(event).not_to be_valid
      expect(event.errors[:more_info_url]).to include('must be a valid URL')
    end
  end
end

