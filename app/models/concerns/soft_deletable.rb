# frozen_string_literal: true

# Concern for soft delete functionality
# Adds deleted_at column handling and scopes
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Default scope excludes soft-deleted records
    default_scope { where(deleted_at: nil) }

    # Scopes for querying deleted/non-deleted records
    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :with_deleted, -> { unscoped }
  end

  # Soft delete the record
  # rubocop:disable Rails/SkipsModelValidations
  def soft_delete
    update_column(:deleted_at, Time.current)
  end

  # Restore a soft-deleted record
  def restore
    update_column(:deleted_at, nil)
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Check if record is soft deleted
  def deleted?
    deleted_at.present?
  end

  # Override destroy to soft delete instead
  def destroy
    soft_delete
  end

  # Provide a way to permanently delete
  def really_destroy!
    self.class.unscoped { super() }
  end
end
