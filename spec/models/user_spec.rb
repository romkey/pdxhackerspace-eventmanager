require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'associations' do
    it { is_expected.to have_many(:events).dependent(:destroy) }
    it { is_expected.to have_many(:event_hosts).dependent(:destroy) }
    it { is_expected.to have_many(:hosted_events).through(:event_hosts) }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(described_class.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(described_class.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(described_class.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(described_class.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(described_class.devise_modules).to include(:validatable)
    end

    it 'includes omniauthable' do
      expect(described_class.devise_modules).to include(:omniauthable)
    end
  end

  describe '#admin?' do
    context 'when user is an admin' do
      let(:user) { create(:user, :admin) }

      it 'returns true' do
        expect(user.admin?).to be true
      end
    end

    context 'when user is not an admin' do
      let(:user) { create(:user) }

      it 'returns false' do
        expect(user.admin?).to be false
      end
    end
  end

  describe '.from_omniauth' do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: 'authentik',
        uid: '12345',
        info: {
          email: 'oauth_user@example.com',
          name: 'OAuth User'
        }
      )
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect do
          described_class.from_omniauth(auth)
        end.to change(described_class, :count).by(1)
      end

      it 'sets the provider and uid' do
        user = described_class.from_omniauth(auth)
        expect(user.provider).to eq('authentik')
        expect(user.uid).to eq('12345')
      end

      it 'sets the name from auth info' do
        user = described_class.from_omniauth(auth)
        expect(user.name).to eq('OAuth User')
      end
    end

    context 'when user already exists' do
      let!(:existing_user) { create(:user, :with_oauth, email: 'oauth_user@example.com', uid: '12345') }

      it 'does not create a new user' do
        expect do
          described_class.from_omniauth(auth)
        end.not_to change(described_class, :count)
      end

      it 'returns the existing user' do
        user = described_class.from_omniauth(auth)
        expect(user.id).to eq(existing_user.id)
      end
    end
  end

  describe 'default role' do
    it 'sets role to user by default' do
      user = create(:user)
      expect(user.role).to eq('user')
    end
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'creates a valid admin user' do
      admin = build(:user, :admin)
      expect(admin).to be_valid
      expect(admin.admin?).to be true
    end

    it 'creates a valid oauth user' do
      oauth_user = build(:user, :with_oauth)
      expect(oauth_user).to be_valid
      expect(oauth_user.provider).to eq('authentik')
      expect(oauth_user.uid).to be_present
    end
  end
end
