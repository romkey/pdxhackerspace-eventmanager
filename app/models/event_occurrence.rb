class EventOccurrence < ApplicationRecord
  belongs_to :event
  has_one_attached :banner_image

  validates :occurs_at, presence: true
  validates :status, inclusion: { in: %w[active postponed cancelled] }

  scope :active, -> { where(status: 'active') }
  scope :postponed, -> { where(status: 'postponed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :upcoming, -> { where('occurs_at >= ?', Time.now).order(:occurs_at) }
  scope :past, -> { where('occurs_at < ?', Time.now).order(occurs_at: :desc) }

  after_update :log_update
  after_save :log_banner_change

  attr_accessor :current_user_for_journal

  # Get the actual description (custom or inherited from event)
  def description
    custom_description.presence || event.description
  end

  # Get the actual duration (override or inherited from event)
  def duration
    duration_override || event.duration
  end

  # Get the banner image (own or inherited from event)
  def banner
    banner_image.attached? ? banner_image : event.banner_image
  end

  # Mark occurrence as postponed
  def postpone!(until_date, reason = nil, user = nil)
    self.current_user_for_journal = user if user
    result = update(status: 'postponed', postponed_until: until_date, cancellation_reason: reason)
    log_status_change('postponed', reason, user) if result && user
    result
  end

  # Mark occurrence as cancelled
  def cancel!(reason = nil, user = nil)
    self.current_user_for_journal = user if user
    result = update(status: 'cancelled', cancellation_reason: reason)
    log_status_change('cancelled', reason, user) if result && user
    result
  end

  # Reactivate occurrence
  def reactivate!(user = nil)
    self.current_user_for_journal = user if user
    result = update(status: 'active', postponed_until: nil, cancellation_reason: nil)
    log_status_change('reactivated', nil, user) if result && user
    result
  end

  # Display name for this occurrence
  def name
    "#{event.title} - #{occurs_at.strftime('%B %d, %Y')}"
  end

  private

  def log_update
    return unless current_user_for_journal
    return unless saved_changes.any?

    tracked_changes = {}
    saved_changes.each do |key, (old_val, new_val)|
      next if %w[updated_at created_at].include?(key)

      if %w[custom_description cancellation_reason].include?(key)
      end
      tracked_changes[key] = { 'from' => old_val, 'to' => new_val }
    end

    return if tracked_changes.empty?

    EventJournal.log_occurrence_change(
      self,
      current_user_for_journal,
      'updated',
      tracked_changes
    )
  end

  def log_status_change(action, reason, user)
    return unless user

    changes_data = { 'status' => action }
    changes_data['reason'] = reason if reason.present?

    EventJournal.log_occurrence_change(
      self,
      user,
      action,
      changes_data
    )
  end

  def log_banner_change
    return unless current_user_for_journal
    return if new_record?

    # Check if banner was added
    return unless banner_image.attached? && banner_image.attachment.blob.created_at > 5.seconds.ago

    EventJournal.log_occurrence_change(
      self,
      current_user_for_journal,
      'banner_added',
      {
        'banner_image' => {
          'filename' => banner_image.filename.to_s,
          'size' => "#{(banner_image.byte_size.to_f / 1024).round(2)} KB",
          'content_type' => banner_image.content_type
        }
      }
    )
  end
end
