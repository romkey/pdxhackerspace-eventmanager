require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class.new(current_user, target_user) }

  let(:target_user) { create(:user) }

  context 'for a guest user' do
    let(:current_user) { nil }

    it 'denies all actions' do
      expect(subject.index?).to be_falsey
      expect(subject.show?).to be_falsey
      expect(subject.create?).to be_falsey
      expect(subject.update?).to be_falsey
      expect(subject.destroy?).to be_falsey
      expect(subject.make_admin?).to be_falsey
    end
  end

  context 'for a regular user' do
    let(:current_user) { create(:user) }

    it 'denies admin actions' do
      expect(subject.index?).to be false
      expect(subject.create?).to be false
      expect(subject.make_admin?).to be false
    end

    it 'allows viewing and editing own profile' do
      own_policy = described_class.new(current_user, current_user)
      expect(own_policy.show?).to be true
      expect(own_policy.update?).to be true
    end

    it 'denies editing other profiles' do
      expect(subject.show?).to be false
      expect(subject.update?).to be false
    end

    it 'denies destroying users' do
      expect(subject.destroy?).to be false
    end
  end

  context 'for an admin user' do
    let(:current_user) { create(:user, :admin) }

    it 'allows all actions' do
      expect(subject.index?).to be true
      expect(subject.show?).to be true
      expect(subject.create?).to be true
      expect(subject.update?).to be true
      expect(subject.make_admin?).to be true
    end

    it 'allows destroying other users' do
      expect(subject.destroy?).to be true
    end

    it 'prevents admins from destroying themselves' do
      self_policy = described_class.new(current_user, current_user)
      expect(self_policy.destroy?).to be false
    end
  end

  describe 'Scope' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:admin) { create(:user, :admin) }

    context 'for an admin' do
      it 'returns all users' do
        scope = Pundit.policy_scope!(admin, User)
        expect(scope).to include(user1, user2, admin)
      end
    end

    context 'for a regular user' do
      it 'returns no users' do
        scope = Pundit.policy_scope!(user1, User)
        expect(scope).to be_empty
      end
    end

    context 'for a guest' do
      it 'returns no users' do
        scope = Pundit.policy_scope!(nil, User)
        expect(scope).to be_empty
      end
    end
  end
end

