require 'rails_helper'

RSpec.describe "Calendar", type: :request do
  let(:user) { create(:user) }

  describe "GET /calendar" do
    let!(:public_event) { create(:event, visibility: 'public', start_time: 1.week.from_now) }
    let!(:members_event) { create(:event, :members_only, start_time: 2.weeks.from_now) }
    let!(:private_event) { create(:event, :private, start_time: 3.weeks.from_now) }

    context "as a guest" do
      it "returns success" do
        get calendar_path
        expect(response).to have_http_status(:success)
      end

      it "shows public event occurrences only" do
        get calendar_path
        expect(response.body).to include(public_event.title)
        expect(response.body).not_to include(members_event.title)
        expect(response.body).not_to include(private_event.title)
      end

      it "displays occurrences" do
        get calendar_path
        public_occurrence = public_event.occurrences.first
        # Calendar shows day number without leading zero
        expect(response.body).to include(public_occurrence.occurs_at.day.to_s)
        expect(response.body).to include(public_occurrence.occurs_at.strftime('%B'))
      end
    end

    context "as a logged-in user" do
      before { sign_in user }

      it "shows public and members event occurrences" do
        get calendar_path
        expect(response.body).to include(public_event.title)
        expect(response.body).to include(members_event.title)
        expect(response.body).not_to include(private_event.title)
      end
    end

    context "as an admin" do
      let(:admin) { create(:user, :admin) }

      before { sign_in admin }

      it "shows all event occurrences" do
        get calendar_path
        expect(response.body).to include(public_event.title)
        expect(response.body).to include(members_event.title)
        expect(response.body).to include(private_event.title)
      end
    end

    context "with no upcoming events" do
      before do
        Event.destroy_all
      end

      it "shows a message about no events" do
        get calendar_path(view: 'list')
        expect(response.body).to include("No upcoming event occurrences")
      end
    end
  end
end
