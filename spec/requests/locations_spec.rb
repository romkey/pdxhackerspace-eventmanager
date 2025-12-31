require 'rails_helper'

RSpec.describe 'Locations' do
  let(:admin) { create(:user, role: 'admin') }
  let(:regular_user) { create(:user, role: 'user') }
  let(:location) { create(:location) }

  describe 'authorization' do
    context 'when not authenticated' do
      it 'redirects to sign in' do
        get locations_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when regular user' do
      before { sign_in regular_user }

      it 'redirects with alert' do
        get locations_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Only admins can manage locations.')
      end
    end

    context 'when admin' do
      before { sign_in admin }

      it 'allows access' do
        get locations_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /locations' do
    before { sign_in admin }

    it 'lists all locations' do
      location1 = create(:location, name: 'Workshop')
      location2 = create(:location, name: 'Main Space')

      get locations_path
      expect(response.body).to include('Workshop')
      expect(response.body).to include('Main Space')
    end

    it 'orders locations alphabetically' do
      create(:location, name: 'Zebra Room')
      create(:location, name: 'Alpha Room')

      get locations_path
      expect(response.body.index('Alpha Room')).to be < response.body.index('Zebra Room')
    end
  end

  describe 'GET /locations/new' do
    before { sign_in admin }

    it 'renders new location form' do
      get new_location_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('New Location')
    end
  end

  describe 'POST /locations' do
    before { sign_in admin }

    context 'with valid attributes' do
      let(:valid_attributes) { { location: { name: 'Conference Room', description: 'Main conference room' } } }

      it 'creates a new location' do
        expect do
          post locations_path, params: valid_attributes
        end.to change(Location, :count).by(1)
      end

      it 'redirects to locations index' do
        post locations_path, params: valid_attributes
        expect(response).to redirect_to(locations_path)
        follow_redirect!
        expect(response.body).to include('Location was successfully created')
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { location: { name: '', description: 'No name' } } }

      it 'does not create location' do
        expect do
          post locations_path, params: invalid_attributes
        end.not_to change(Location, :count)
      end

      it 'renders new template with errors' do
        post locations_path, params: invalid_attributes
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('error')
      end
    end

    context 'with duplicate name' do
      it 'does not create location' do
        create(:location, name: 'Workshop')

        expect do
          post locations_path, params: { location: { name: 'Workshop' } }
        end.not_to change(Location, :count)
      end
    end
  end

  describe 'GET /locations/:id/edit' do
    before { sign_in admin }

    it 'renders edit form' do
      get edit_location_path(location)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Edit Location')
      expect(response.body).to include(location.name)
    end
  end

  describe 'PATCH /locations/:id' do
    before { sign_in admin }

    context 'with valid attributes' do
      it 'updates the location' do
        patch location_path(location), params: { location: { name: 'Updated Name' } }
        location.reload
        expect(location.name).to eq('Updated Name')
      end

      it 'redirects to locations index' do
        patch location_path(location), params: { location: { name: 'Updated' } }
        expect(response).to redirect_to(locations_path)
        follow_redirect!
        expect(response.body).to include('Location was successfully updated')
      end
    end

    context 'with invalid attributes' do
      it 'does not update the location' do
        original_name = location.name
        patch location_path(location), params: { location: { name: '' } }
        location.reload
        expect(location.name).to eq(original_name)
      end

      it 'renders edit template' do
        patch location_path(location), params: { location: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /locations/:id' do
    before { sign_in admin }

    it 'destroys the location' do
      location # create it first
      expect do
        delete location_path(location)
      end.to change(Location, :count).by(-1)
    end

    it 'redirects to locations index' do
      delete location_path(location)
      expect(response).to redirect_to(locations_url)
      follow_redirect!
      expect(response.body).to include('Location was successfully deleted')
    end

    it 'nullifies location_id in events' do
      event = create(:event, location:)
      delete location_path(location)
      event.reload
      expect(event.location_id).to be_nil
    end
  end
end
