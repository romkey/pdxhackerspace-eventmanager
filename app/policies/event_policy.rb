class EventPolicy < ApplicationPolicy
  def index?
    true # Anyone can view events list
  end

  def show?
    # Draft events - only author and admins can view
    return false if record.draft? && user.present? && !user.admin? && user != record.user
    return false if record.draft? && user.blank?

    # Public events - anyone can view
    return true if record.public?

    # Members events - signed in users can view
    return true if record.members_only? && user.present?

    # Private events - only owner and admin can view
    return true if record.private? && user.present? && (user.admin? || user == record.user)

    false
  end

  def create?
    user.present? && (user.admin? || user.can_create_events?)
  end

  def update?
    user.present? && (user.admin? || record.hosted_by?(user))
  end

  def destroy?
    user.present? && (user.admin? || user == record.user)
  end

  def postpone?
    update?
  end

  def cancel?
    update?
  end

  def reactivate?
    update?
  end

  class Scope < Scope
    def resolve
      if user.blank?
        # Not signed in - only show published public events
        scope.published.public_events
      elsif user.admin?
        # Admins can see all events (including drafts)
        scope.all
      else
        # Regular users can see published public, members, their own private events, and their own drafts
        scope.where(
          '(draft = ? AND (visibility = ? OR visibility = ? OR (visibility = ? AND user_id = ?))) OR (draft = ? AND user_id = ?)',
          false, 'public', 'members', 'private', user.id, true, user.id
        )
      end
    end
  end
end
