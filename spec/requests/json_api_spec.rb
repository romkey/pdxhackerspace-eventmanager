require 'rails_helper'

RSpec.describe "JSON API", type: :request do
  describe "GET /events.json" do
    let!(:public_event) { create(:event, visibility: 'public', title: 'Public Event', start_time: 1.week.from_now) }
    let!(:members_event) { create(:event, :members_only, title: 'Members Event', start_time: 2.weeks.from_now) }
    let!(:private_event) { create(:event, :private, title: 'Private Event', start_time: 3.weeks.from_now) }
    let!(:cancelled_event) { create(:event, :cancelled, visibility: 'public', title: 'Cancelled Event') }

    before do
      # Ensure occurrences are created
      [public_event, members_event, private_event, cancelled_event].each(&:generate_occurrences)
    end

    it "returns JSON format" do
      get events_path, headers: { 'Accept' => 'application/json' }
      expect(response.content_type).to include('application/json')
      expect(response).to have_http_status(:success)
    end

    it "returns public events with full details and non-public events as 'Private Event'" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      event_titles = json['events'].pluck('title')
      # Public event should show its actual title
      expect(event_titles).to include('Public Event')
      # Non-public events should show as 'Private Event'
      expect(event_titles).to include('Private Event')
      # Should not show the actual titles of non-public events
      expect(event_titles).not_to include('Members Event')
      # Cancelled events should not appear at all
      expect(event_titles).not_to include('Cancelled Event')
    end

    it "includes both members and private events as 'Private Event'" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      # Find the private event entries (both members and private visibility map to "Private Event")
      private_events = json['events'].select { |e| e['title'] == 'Private Event' }
      expect(private_events.length).to eq(2) # members_event and private_event
    end

    it "hides details for non-public events" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      private_event_json = json['events'].find { |e| e['title'] == 'Private Event' }
      expect(private_event_json['description']).to be_nil
      expect(private_event_json['start_time']).to be_nil
      expect(private_event_json['duration']).to be_nil
      expect(private_event_json['hosts']).to eq([])
      expect(private_event_json['location']).to be_nil
      expect(private_event_json['banner_url']).to be_nil
    end

    it "shows occurrence times for non-public events (for scheduling)" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      private_event_json = json['events'].find { |e| e['title'] == 'Private Event' }
      expect(private_event_json['occurrences']).to be_an(Array)
      return if private_event_json['occurrences'].empty?

      occ = private_event_json['occurrences'].first
      expect(occ['occurs_at']).to be_present
      expect(occ['description']).to be_nil
    end

    it "excludes events that have already passed" do
      # Create an event with only past occurrences
      past_event = create(:event, visibility: 'public', title: 'Past Event', start_time: 2.weeks.ago)
      # Manually create a past occurrence
      past_event.occurrences.destroy_all
      create(:event_occurrence, event: past_event, occurs_at: 1.week.ago)

      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      event_titles = json['events'].pluck('title')
      expect(event_titles).not_to include('Past Event')
    end

    it "includes events currently in progress" do
      # Create an event that started 30 minutes ago with 2 hour duration (so still in progress)
      in_progress_event = create(:event, visibility: 'public', title: 'In Progress Event', start_time: 30.minutes.ago, duration: 120)
      in_progress_event.occurrences.destroy_all
      create(:event_occurrence, event: in_progress_event, occurs_at: 30.minutes.ago)

      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      event_titles = json['events'].pluck('title')
      expect(event_titles).to include('In Progress Event')
    end

    it "includes event metadata" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      expect(json).to have_key('events')
      expect(json).to have_key('generated_at')
      expect(json).to have_key('count')
    end

    it "includes event details" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      event = json['events'].first

      expect(event).to have_key('id')
      expect(event).to have_key('title')
      expect(event).to have_key('description')
      expect(event).to have_key('start_time')
      expect(event).to have_key('duration')
      expect(event).to have_key('recurrence_type')
      expect(event).to have_key('hosts')
      expect(event).to have_key('occurrences')
    end

    it "includes hosts as simple array of names" do
      user = create(:user, name: 'John Doe')
      event = create(:event, visibility: 'public', user: user)

      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      event_json = json['events'].find { |e| e['id'] == event.id }

      expect(event_json['hosts']).to be_an(Array)
      expect(event_json['hosts']).to include('John Doe')
      # Ensure no email addresses are exposed
      expect(event_json['hosts'].to_s).not_to include('@')
    end

    it "includes upcoming occurrences" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      event = json['events'].first

      expect(event['occurrences']).to be_an(Array)
      if event['occurrences'].any?
        occurrence = event['occurrences'].first
        expect(occurrence).to have_key('id')
        expect(occurrence).to have_key('occurs_at')
        expect(occurrence).to have_key('status')
        expect(occurrence).to have_key('duration')
        expect(occurrence).to have_key('description')
      end
    end

    it "includes banner URLs when present" do
      event_with_banner = create(:event, :with_banner, visibility: 'public')

      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      event_json = json['events'].find { |e| e['id'] == event_with_banner.id }

      expect(event_json['banner_url']).to be_present
      expect(event_json['banner_url']).to include('rails/active_storage')
    end

    it "sets banner_url to null when no banner" do
      get events_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      event = json['events'].find { |e| e['id'] == public_event.id }

      expect(event['banner_url']).to be_nil
    end

    it "does not require authentication" do
      get events_path, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /calendar.json" do
    let!(:public_event) { create(:event, visibility: 'public', title: 'Public Event') }
    let!(:members_event) { create(:event, :members_only, title: 'Members Event') }
    let!(:private_event) { create(:event, :private, title: 'Private Event') }

    before do
      # Create some occurrences
      create(:event_occurrence, event: public_event, occurs_at: 1.week.from_now)
      create(:event_occurrence, event: public_event, occurs_at: 2.weeks.from_now)
      create(:event_occurrence, event: members_event, occurs_at: 1.week.from_now)
      create(:event_occurrence, event: private_event, occurs_at: 1.week.from_now)
    end

    it "returns JSON format" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      expect(response.content_type).to include('application/json')
      expect(response).to have_http_status(:success)
    end

    it "returns only public event occurrences" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      event_titles = json['occurrences'].map { |o| o['event']['title'] }
      expect(event_titles).to include('Public Event')
      expect(event_titles).not_to include('Members Event', 'Private Event')
    end

    it "does not include grouped_by_month" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      expect(json).not_to have_key('grouped_by_month')
    end

    it "includes occurrence metadata" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      expect(json).to have_key('occurrences')
      expect(json).to have_key('generated_at')
      expect(json).to have_key('count')
    end

    it "includes occurrence details" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      return if json['occurrences'].empty?

      occurrence = json['occurrences'].first
      expect(occurrence).to have_key('id')
      expect(occurrence).to have_key('occurs_at')
      expect(occurrence).to have_key('status')
      expect(occurrence).to have_key('duration')
      expect(occurrence).to have_key('description')
      expect(occurrence).to have_key('event')
    end

    it "includes event information for each occurrence" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      return if json['occurrences'].empty?

      occurrence = json['occurrences'].first
      event = occurrence['event']

      expect(event).to have_key('id')
      expect(event).to have_key('title')
      expect(event).to have_key('hosts')
      expect(event).to have_key('visibility')
      expect(event).to have_key('open_to')
    end

    it "includes hosts as simple array without emails" do
      user = create(:user, name: 'Jane Doe')
      event = create(:event, visibility: 'public', user: user)
      create(:event_occurrence, event: event, occurs_at: 1.week.from_now)

      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      occurrence = json['occurrences'].find { |o| o['event']['id'] == event.id }

      expect(occurrence['event']['hosts']).to be_an(Array)
      expect(occurrence['event']['hosts']).to include('Jane Doe')
      # Ensure no email addresses
      expect(occurrence['event']['hosts'].to_s).not_to include('@')
    end

    it "sorts occurrences by date (earliest first)" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)

      return if json['occurrences'].length < 2

      dates = json['occurrences'].map { |o| Time.parse(o['occurs_at']) }
      expect(dates).to eq(dates.sort)
    end

    it "includes postponed occurrence details" do
      postponed_occurrence = create(:event_occurrence, :postponed, event: public_event, occurs_at: 3.weeks.from_now)

      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      occ_json = json['occurrences'].find { |o| o['id'] == postponed_occurrence.id }

      expect(occ_json['status']).to eq('postponed')
      expect(occ_json['postponed_until']).to be_present
      expect(occ_json['cancellation_reason']).to be_present
    end

    it "includes cancelled occurrence details" do
      cancelled_occurrence = create(:event_occurrence, :cancelled, event: public_event, occurs_at: 4.weeks.from_now)

      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      occ_json = json['occurrences'].find { |o| o['id'] == cancelled_occurrence.id }

      expect(occ_json['status']).to eq('cancelled')
      expect(occ_json['cancellation_reason']).to be_present
    end

    it "includes banner URLs" do
      event_with_banner = create(:event, :with_banner, visibility: 'public')
      occ_with_banner = create(:event_occurrence, event: event_with_banner, occurs_at: 5.weeks.from_now)

      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      occ_json = json['occurrences'].find { |o| o['id'] == occ_with_banner.id }

      expect(occ_json['banner_url']).to be_present
    end

    it "indicates when occurrence has custom banner" do
      event = create(:event, :with_banner, visibility: 'public')
      occ_with_custom = create(:event_occurrence, :with_banner, event: event, occurs_at: 6.weeks.from_now)

      get calendar_path, headers: { 'Accept' => 'application/json' }
      json = JSON.parse(response.body)
      occ_json = json['occurrences'].find { |o| o['id'] == occ_with_custom.id }

      expect(occ_json['has_custom_banner']).to be true
    end

    it "does not require authentication" do
      get calendar_path, headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:success)
    end
  end
end
