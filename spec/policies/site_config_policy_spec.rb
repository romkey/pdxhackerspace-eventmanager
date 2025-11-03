require 'rails_helper'

RSpec.describe SiteConfigPolicy, type: :policy do
  let(:site_config) { create(:site_config) }

  describe 'permissions' do
    context 'for a guest user' do
      let(:policy) { described_class.new(nil, site_config) }

      it 'denies all actions' do
        expect(policy.edit?).to be_falsey
        expect(policy.update?).to be_falsey
      end
    end

    context 'for a regular user' do
      let(:user) { create(:user) }
      let(:policy) { described_class.new(user, site_config) }

      it 'denies all actions' do
        expect(policy.edit?).to be false
        expect(policy.update?).to be false
      end
    end

    context 'for an admin user' do
      let(:admin) { create(:user, :admin) }
      let(:policy) { described_class.new(admin, site_config) }

      it 'allows all actions' do
        expect(policy.edit?).to be true
        expect(policy.update?).to be true
      end
    end
  end

  describe 'Scope' do
    let!(:site_config) { create(:site_config) }
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }

    context 'for a regular user' do
      it 'returns no configs' do
        scope = Pundit.policy_scope!(user, SiteConfig)
        expect(scope).to be_empty
      end
    end

    context 'for an admin' do
      it 'returns all configs' do
        scope = Pundit.policy_scope!(admin, SiteConfig)
        expect(scope).to include(site_config)
      end
    end

    context 'for a guest' do
      it 'returns no configs' do
        scope = Pundit.policy_scope!(nil, SiteConfig)
        expect(scope).to be_empty
      end
    end
  end
end
