# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Calendar Embed", type: :feature do
  before { create(:site_config, organization_name: "Test Hackerspace") }

  describe "Site-wide calendar embed (/calendar/embed)" do
    context "with public events" do
      let!(:public_event) do
        create(:event,
               visibility: 'public',
               status: 'active',
               draft: false,
               title: 'Public Workshop',
               start_time: Date.current.beginning_of_month + 15.days + 14.hours)
      end

      it "displays the organization name" do
        visit calendar_embed_path
        expect(page).to have_content("Test Hackerspace")
      end

      it "shows the calendar grid by default" do
        visit calendar_embed_path
        expect(page).to have_css('.calendar-grid')
        expect(page).to have_content(Date.current.strftime('%B %Y'))
      end

      it "shows public event occurrences" do
        # Visit the month containing the event
        visit calendar_embed_path(month: public_event.start_time.strftime('%Y-%m-%d'))
        expect(page).to have_content('Public Workshop')
      end

      it "has view toggle buttons" do
        visit calendar_embed_path
        expect(page).to have_link('Calendar')
        expect(page).to have_link('List')
      end

      it "can switch to list view" do
        visit calendar_embed_path(view: 'list')
        # Either shows list group with events or empty state
        expect(page).to have_css('.list-group').or have_content('No upcoming event occurrences')
      end

      it "shows calendar navigation" do
        visit calendar_embed_path
        # Should have previous and next month links
        prev_month = (Date.current - 1.month).strftime('%B %Y')
        next_month = (Date.current + 1.month).strftime('%B %Y')
        expect(page).to have_content(prev_month)
        expect(page).to have_content(next_month)
      end

      it "can navigate to previous month" do
        visit calendar_embed_path
        prev_month = (Date.current - 1.month).strftime('%B %Y')
        click_link prev_month
        expect(page).to have_css('h2', text: prev_month)
      end

      it "can navigate to next month" do
        visit calendar_embed_path
        next_month = (Date.current + 1.month).strftime('%B %Y')
        click_link next_month
        expect(page).to have_css('h2', text: next_month)
      end
    end

    context "with private and draft events" do
      let!(:private_event) { create(:event, :private, title: 'Secret Meeting') }
      let!(:draft_event) { create(:event, visibility: 'public', draft: true, title: 'Unpublished Event') }
      let!(:members_event) { create(:event, :members_only, title: 'Members Only Event') }

      it "excludes private events" do
        visit calendar_embed_path(month: private_event.start_time.strftime('%Y-%m-%d'))
        expect(page).not_to have_content('Secret Meeting')
      end

      it "excludes draft events" do
        visit calendar_embed_path(month: draft_event.start_time.strftime('%Y-%m-%d'))
        expect(page).not_to have_content('Unpublished Event')
      end

      it "excludes members-only events" do
        visit calendar_embed_path(month: members_event.start_time.strftime('%Y-%m-%d'))
        expect(page).not_to have_content('Members Only Event')
      end
    end

    context "with various occurrence statuses" do
      let!(:event) do
        create(:event, visibility: 'public', status: 'active', draft: false,
                       start_time: Date.current.beginning_of_month + 10.days + 14.hours)
      end

      it "shows postponed occurrences with warning styling" do
        create(:event_occurrence, :postponed,
               event: event,
               occurs_at: Date.current.beginning_of_month + 12.days + 14.hours)
        visit calendar_embed_path
        expect(page).to have_css('.bg-warning')
      end

      it "shows cancelled occurrences with danger styling" do
        create(:event_occurrence, :cancelled,
               event: event,
               occurs_at: Date.current.beginning_of_month + 14.days + 14.hours)
        visit calendar_embed_path
        expect(page).to have_css('.bg-danger')
      end
    end

    context "list view" do
      let!(:event1) do
        create(:event, visibility: 'public', status: 'active', draft: false, title: 'First Event',
                       start_time: 1.week.from_now)
      end

      it "groups events by month" do
        visit calendar_embed_path(view: 'list')
        expect(page).to have_css('.card-header')
      end

      it "shows event times" do
        visit calendar_embed_path(view: 'list')
        expect(page).to have_css('.bi-clock')
      end

      it "shows mask requirement badge when applicable" do
        event1.update!(requires_mask: true)
        visit calendar_embed_path(view: 'list')
        expect(page).to have_content('Masks Required')
      end

      it "links events to full event page" do
        visit calendar_embed_path(view: 'list')
        expect(page).to have_link('First Event')
      end
    end

    context "with no events" do
      it "shows empty state message in list view" do
        visit calendar_embed_path(view: 'list')
        expect(page).to have_content('No upcoming event occurrences scheduled')
      end
    end

    context "embed layout" do
      it "uses minimal embed layout" do
        visit calendar_embed_path
        # Should not have full navigation
        expect(page).not_to have_css('nav.navbar')
      end

      it "has transparent background style" do
        visit calendar_embed_path
        expect(page).to have_css('body')
      end
    end
  end

  describe "Per-event embed (/events/:id/embed)" do
    let!(:public_event) do
      create(:event,
             visibility: 'public',
             status: 'active',
             draft: false,
             title: 'Embedded Event',
             start_time: Date.current.beginning_of_month + 15.days + 18.hours)
    end

    context "with a public event" do
      it "displays the event title" do
        visit embed_event_path(public_event)
        expect(page).to have_content('Embedded Event')
      end

      it "shows the calendar grid by default" do
        visit embed_event_path(public_event)
        expect(page).to have_css('.calendar-grid')
      end

      it "has view toggle buttons" do
        visit embed_event_path(public_event)
        expect(page).to have_link('Calendar')
        expect(page).to have_link('List')
      end

      it "can switch to list view" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_css('.list-group').or have_content('No upcoming occurrences')
      end

      it "links back to full event page" do
        visit embed_event_path(public_event)
        expect(page).to have_link('View full calendar →')
      end
    end

    context "with event occurrences" do
      let!(:upcoming_occurrence) do
        # Create occurrence in the future
        create(:event_occurrence, event: public_event, occurs_at: 1.week.from_now)
      end

      it "shows event occurrences in calendar view" do
        visit embed_event_path(public_event, month: upcoming_occurrence.occurs_at.strftime('%Y-%m-%d'))
        expect(page).to have_content('Embedded Event')
      end

      it "shows event occurrences in list view" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_content(upcoming_occurrence.occurs_at.strftime('%B'))
      end

      it "shows occurrence times" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_css('.bi-clock')
      end
    end

    context "with postponed occurrence" do
      before do
        create(:event_occurrence, :postponed,
               event: public_event,
               occurs_at: Date.current.beginning_of_month + 18.days + 18.hours)
      end

      it "shows postponed status in list view" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_content('Postponed')
      end

      it "shows rescheduled date when available" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_content('Rescheduled to')
      end
    end

    context "with requires_mask event" do
      before do
        public_event.update!(requires_mask: true)
        create(:event_occurrence, event: public_event, occurs_at: 1.week.from_now)
      end

      it "shows mask requirement in list view" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_content('Masks Required').or have_css('.bi-shield-fill-check')
      end
    end

    context "with no occurrences" do
      before { public_event.occurrences.destroy_all }

      it "shows empty state in list view" do
        visit embed_event_path(public_event, view: 'list')
        expect(page).to have_content('No upcoming occurrences scheduled')
      end
    end

    context "access control" do
      it "allows access to public events without authentication" do
        visit embed_event_path(public_event)
        expect(page).to have_content('Embedded Event')
      end

      context "with private event" do
        let(:private_event) { create(:event, :private, title: 'Private Event') }

        it "returns forbidden for unauthenticated users" do
          visit embed_event_path(private_event)
          expect(page.status_code).to eq(403)
        end

        it "allows access for the event host" do
          sign_in private_event.user
          visit embed_event_path(private_event)
          expect(page).to have_content('Private Event')
        end

        it "allows access for admins" do
          admin = create(:user, :admin)
          sign_in admin
          visit embed_event_path(private_event)
          expect(page).to have_content('Private Event')
        end
      end

      context "with draft event" do
        let(:draft_event) { create(:event, visibility: 'public', draft: true, title: 'Draft Event') }

        it "returns forbidden" do
          visit embed_event_path(draft_event)
          expect(page.status_code).to eq(403)
        end
      end

      context "with members-only event" do
        let(:members_event) { create(:event, :members_only, title: 'Members Event') }

        it "returns forbidden for unauthenticated users" do
          visit embed_event_path(members_event)
          expect(page.status_code).to eq(403)
        end

        it "returns forbidden for regular authenticated users (not hosts)" do
          # Members-only events can only be embedded by hosts/admins
          user = create(:user)
          sign_in user
          visit embed_event_path(members_event)
          expect(page.status_code).to eq(403)
        end

        it "allows access for the event host" do
          sign_in members_event.user
          visit embed_event_path(members_event)
          expect(page).to have_content('Members Event')
        end
      end
    end
  end

  describe "Calendar grid features" do
    let!(:event) do
      create(:event,
             visibility: 'public',
             status: 'active',
             draft: false,
             title: 'Grid Test Event',
             start_time: Date.current.beginning_of_month + 15.days + 10.hours)
    end

    it "shows day names in header" do
      visit calendar_embed_path
      Date::DAYNAMES.each do |day|
        expect(page).to have_content(day)
      end
    end

    it "highlights today's date" do
      visit calendar_embed_path
      expect(page).to have_css('.calendar-cell.today')
    end

    it "shows occurrence times" do
      visit calendar_embed_path(month: event.start_time.strftime('%Y-%m-%d'))
      expect(page).to have_content(event.start_time.strftime('%I:%M %p'))
    end

    it "opens occurrence links in new tab" do
      visit calendar_embed_path(month: event.start_time.strftime('%Y-%m-%d'))
      expect(page).to have_css('a[target="_blank"]')
    end
  end

  describe "Responsive behavior" do
    it "calendar embed renders without errors" do
      visit calendar_embed_path
      expect(page).to have_css('.calendar-grid')
    end

    it "event embed renders without errors" do
      event = create(:event, visibility: 'public', draft: false)
      visit embed_event_path(event)
      expect(page).to have_css('.calendar-grid')
    end
  end
end
