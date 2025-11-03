class Event < ApplicationRecord
  belongs_to :user # Original creator
  has_many :event_hosts, dependent: :destroy
  has_many :hosts, through: :event_hosts, source: :user
  has_many :event_occurrences, dependent: :destroy
  has_many :occurrences, class_name: 'EventOccurrence', dependent: :destroy
  has_many :event_journals, dependent: :destroy
  has_one_attached :banner_image

  before_create :generate_ical_token
  after_create :add_creator_as_host
  after_create :generate_initial_occurrences
  after_create :log_creation
  after_update :log_update
  after_update :regenerate_occurrences_if_needed
  after_save :log_banner_change

  attr_accessor :current_user_for_journal

  validates :title, presence: true
  validates :start_time, presence: true
  validates :duration, numericality: { greater_than: 0 }
  validates :recurrence_type, inclusion: { in: %w[once weekly monthly custom] }
  validates :status, inclusion: { in: %w[active postponed cancelled] }
  validates :visibility, inclusion: { in: %w[public members private] }
  validates :open_to, inclusion: { in: %w[public members private] }
  validates :more_info_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  scope :active, -> { where(status: 'active') }
  scope :postponed, -> { where(status: 'postponed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :public_events, -> { where(visibility: 'public') }
  scope :members_events, -> { where(visibility: 'members') }
  scope :private_events, -> { where(visibility: 'private') }

  # Get occurrence dates for a date range (from IceCube schedule)
  def occurrence_dates(start_date, end_date)
    return [] unless recurrence_rule.present?

    schedule = IceCube::Schedule.from_yaml(recurrence_rule)
    schedule.occurrences_between(start_date, end_date)
  end

  # Check if event is recurring
  def recurring?
    recurrence_type != 'once'
  end

  # Visibility helpers
  def public?
    visibility == 'public'
  end

  def members_only?
    visibility == 'members'
  end

  def private?
    visibility == 'private'
  end

  # Mark event as postponed
  def postpone!(until_date, reason = nil)
    update(status: 'postponed', postponed_until: until_date, cancellation_reason: reason)
  end

  # Mark event as cancelled
  def cancel!(reason = nil)
    update(status: 'cancelled', cancellation_reason: reason)
  end

  # Reactivate event
  def reactivate!
    update(status: 'active', postponed_until: nil, cancellation_reason: nil)
  end

  # Host management
  def hosted_by?(user)
    return false unless user

    user.admin? || hosts.include?(user)
  end

  def add_host(user)
    hosts << user unless hosted_by?(user)
  end

  def remove_host(user)
    # Don't allow removing the creator unless they're not the only host
    return false if user == self.user && hosts.count <= 1

    event_hosts.find_by(user: user)&.destroy
  end

  def creator
    user
  end

  # Generate future occurrences based on recurrence rules
  def generate_occurrences(limit = nil)
    limit ||= max_occurrences || 5

    if recurrence_type == 'once'
      # One-time event - create single occurrence if it doesn't exist
      occurrences.find_or_create_by!(occurs_at: start_time.to_datetime)
    elsif recurrence_rule.present?
      # Recurring event - generate occurrences
      schedule = IceCube::Schedule.from_yaml(recurrence_rule)
      future_dates = schedule.occurrences_between(Time.now, 1.year.from_now).first(limit)

      future_dates.each do |date|
        # Convert Time to DateTime for PostgreSQL
        occurrences.find_or_create_by!(occurs_at: date.to_datetime)
      end
    end
  end

  # Get upcoming active occurrences
  def upcoming_occurrences(limit = nil)
    limit ||= max_occurrences || 5
    occurrences.upcoming.active.limit(limit)
  end

  # Regenerate occurrences (useful after recurrence rule changes)
  def regenerate_future_occurrences!
    # Delete future occurrences that haven't been modified
    occurrences.where('occurs_at > ? AND status = ?', Time.now, 'active').destroy_all
    generate_occurrences
  end

  # Build IceCube schedule from parameters
  def self.build_schedule(start_time, recurrence_type, recurrence_params = {})
    schedule = IceCube::Schedule.new(start_time)

    case recurrence_type
    when 'weekly'
      # Weekly on specific day(s)
      days = recurrence_params[:days] || [start_time.wday]
      rule = IceCube::Rule.weekly.day(*days)
      schedule.add_recurrence_rule(rule)
    when 'monthly'
      if recurrence_params[:occurrence] && recurrence_params[:day]
        # e.g., "first Tuesday", "third Monday"
        occurrence = recurrence_params[:occurrence].to_sym # :first, :second, :third, :fourth, :last
        day = recurrence_params[:day].to_sym # :monday, :tuesday, etc.
        rule = IceCube::Rule.monthly.day_of_week(day => [occurrence])
        schedule.add_recurrence_rule(rule)
      else
        # Monthly on the same day of month
        rule = IceCube::Rule.monthly.day_of_month(start_time.day)
        schedule.add_recurrence_rule(rule)
      end
    when 'custom'
      # For more complex recurrence patterns
      # Can be extended based on specific needs
    end

    schedule
  end

  private

  def generate_ical_token
    self.ical_token = SecureRandom.urlsafe_base64(32)
  end

  def add_creator_as_host
    # Automatically add the creator as the first host
    hosts << user unless hosted_by?(user)
  end

  def generate_initial_occurrences
    # Generate occurrences when event is first created
    generate_occurrences
  end

  def regenerate_occurrences_if_needed
    # Regenerate if recurrence settings changed
    return unless saved_change_to_recurrence_rule? || saved_change_to_start_time? || saved_change_to_max_occurrences?

    regenerate_future_occurrences!
  end

  def log_creation
    return unless current_user_for_journal

    EventJournal.log_event_change(
      self,
      current_user_for_journal,
      'created',
      {
        'title' => title,
        'recurrence_type' => recurrence_type,
        'visibility' => visibility,
        'open_to' => open_to
      }
    )
  end

  def log_update
    return unless current_user_for_journal
    return unless saved_changes.any?

    tracked_changes = {}
    saved_changes.each do |key, (old_val, new_val)|
      # Skip timestamps and internal fields
      next if %w[updated_at created_at ical_token].include?(key)

      # Store full text for text fields
      tracked_changes[key] = if %w[title description more_info_url cancellation_reason].include?(key)
                               { 'from' => old_val, 'to' => new_val }
                             else
                               { 'from' => old_val, 'to' => new_val }
                             end
    end

    return if tracked_changes.empty?

    EventJournal.log_event_change(
      self,
      current_user_for_journal,
      'updated',
      tracked_changes
    )
  end

  def log_banner_change
    return unless current_user_for_journal
    return if new_record?

    # Check if banner was added
    return unless banner_image.attached? && banner_image.attachment.blob.created_at > 5.seconds.ago

    EventJournal.log_event_change(
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
