class EventPolicy < ApplicationPolicy
  def index?
    true # Anyone can view events list
  end

  def show?
    # Public events - anyone can view
    return true if record.public?

    # Members events - signed in users can view
    return true if record.members_only? && user.present?

    # Private events - only owner and admin can view
    return true if record.private? && user.present? && (user.admin? || user == record.user)

    false
  end

  def create?
    user.present?
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
        # Not signed in - only show public events
        scope.public_events
      elsif user.admin?
        # Admins can see all events
        scope.all
      else
        # Regular users can see public, members, and their own private events
        scope.where(
          'visibility = ? OR visibility = ? OR (visibility = ? AND user_id = ?)',
          'public', 'members', 'private', user.id
        )
      end
    end
  end
end
