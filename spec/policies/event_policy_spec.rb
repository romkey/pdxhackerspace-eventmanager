require 'rails_helper'

RSpec.describe EventPolicy, type: :policy do
  let(:creator) { create(:user, role: 'admin') }
  let(:event) { create(:event, user: creator, visibility: 'public') }

  describe 'permissions' do
    context 'for a guest user' do
      let(:policy) { described_class.new(nil, event) }

      context 'with a public event' do
        it 'allows viewing' do
          expect(policy.show?).to be true
          expect(policy.index?).to be true
        end

        it 'denies creating' do
          new_event = build(:event)
          new_policy = described_class.new(nil, new_event)
          expect(new_policy.create?).to be false
          expect(new_policy.new?).to be false
        end

        it 'denies management actions' do
          expect(policy.edit?).to be false
          expect(policy.update?).to be false
          expect(policy.destroy?).to be false
          expect(policy.postpone?).to be false
          expect(policy.cancel?).to be false
          expect(policy.reactivate?).to be false
        end
      end

      context 'with a members-only event' do
        let(:event) { create(:event, :members_only, user: creator) }
        let(:policy) { described_class.new(nil, event) }

        it 'denies viewing' do
          expect(policy.show?).to be false
        end
      end

      context 'with a private event' do
        let(:event) { create(:event, :private, user: creator) }
        let(:policy) { described_class.new(nil, event) }

        it 'denies viewing' do
          expect(policy.show?).to be false
        end
      end
    end

    context 'for a regular user (not creator or host)' do
      let(:user) { create(:user) }
      let(:policy) { described_class.new(user, event) }

      context 'with a public event' do
        it 'allows viewing but not creating' do
          expect(policy.show?).to be true
          expect(policy.index?).to be true

          new_event = build(:event)
          new_policy = described_class.new(user, new_event)
          expect(new_policy.create?).to be false
        end

        it 'denies management actions' do
          expect(policy.edit?).to be false
          expect(policy.update?).to be false
          expect(policy.destroy?).to be false
          expect(policy.postpone?).to be false
          expect(policy.cancel?).to be false
          expect(policy.reactivate?).to be false
        end
      end

      context 'with a members-only event' do
        let(:event) { create(:event, :members_only, user: creator) }

        it 'allows viewing' do
          expect(policy.show?).to be true
        end
      end

      context 'with a private event' do
        let(:event) { create(:event, :private, user: creator) }

        it 'denies viewing' do
          expect(policy.show?).to be false
        end
      end
    end

    context 'for the event creator' do
      let(:policy) { described_class.new(creator, event) }

      it 'allows all actions' do
        expect(policy.show?).to be true
        expect(policy.index?).to be true
        expect(policy.create?).to be true
        expect(policy.new?).to be true
        expect(policy.edit?).to be true
        expect(policy.update?).to be true
        expect(policy.destroy?).to be true
        expect(policy.postpone?).to be true
        expect(policy.cancel?).to be true
        expect(policy.reactivate?).to be true
      end

      context 'with a private event' do
        let(:event) { create(:event, :private, user: creator) }

        it 'allows viewing and editing own private event' do
          expect(policy.show?).to be true
          expect(policy.edit?).to be true
        end
      end
    end

    context 'for an event host (not creator)' do
      let(:host_user) { create(:user) }
      let(:policy) { described_class.new(host_user, event) }

      before do
        event.add_host(host_user)
      end

      it 'allows management but not deletion' do
        expect(policy.show?).to be true
        expect(policy.edit?).to be true
        expect(policy.update?).to be true
        expect(policy.postpone?).to be true
        expect(policy.cancel?).to be true
        expect(policy.reactivate?).to be true
      end

      it 'denies deletion' do
        expect(policy.destroy?).to be false
      end
    end

    context 'for an admin user' do
      let(:admin) { create(:user, :admin) }
      let(:policy) { described_class.new(admin, event) }

      it 'allows all actions' do
        expect(policy.show?).to be true
        expect(policy.index?).to be true
        expect(policy.create?).to be true
        expect(policy.new?).to be true
        expect(policy.edit?).to be true
        expect(policy.update?).to be true
        expect(policy.destroy?).to be true
        expect(policy.postpone?).to be true
        expect(policy.cancel?).to be true
        expect(policy.reactivate?).to be true
      end

      context 'with a private event' do
        let(:event) { create(:event, :private, user: creator) }

        it 'allows viewing and editing any private event' do
          expect(policy.show?).to be true
          expect(policy.edit?).to be true
        end
      end
    end
  end

  describe 'Scope' do
    let!(:public_event) { create(:event, visibility: 'public') }
    let!(:members_event) { create(:event, :members_only) }
    let!(:private_event) { create(:event, :private) }
    let(:user) { create(:user) }
    let(:admin) { create(:user, :admin) }

    context 'for a guest' do
      it 'returns only public events' do
        scope = Pundit.policy_scope!(nil, Event)
        expect(scope).to include(public_event)
        expect(scope).not_to include(members_event, private_event)
      end
    end

    context 'for a regular user' do
      it 'returns public and members events' do
        scope = Pundit.policy_scope!(user, Event)
        expect(scope).to include(public_event, members_event)
        expect(scope).not_to include(private_event)
      end
    end

    context 'for an admin' do
      it 'returns all events' do
        scope = Pundit.policy_scope!(admin, Event)
        expect(scope).to include(public_event, members_event, private_event)
      end
    end

    context 'for a user who hosts a private event' do
      let(:user_private_event) { create(:event, :private, user: user) }

      it 'includes their hosted private event' do
        user_private_event # Create it
        scope = Pundit.policy_scope!(user, Event)
        expect(scope).to include(user_private_event)
      end
    end
  end
end
