# frozen_string_literal: true

# Service object for generating and managing event occurrences
# Extracted from Event model to centralize IceCube scheduling and DST handling logic
class OccurrenceGenerator
  attr_reader :event

  def initialize(event)
    @event = event
  end

  # Generate future occurrences based on recurrence rules
  def generate(limit: nil)
    return if event.permanently_cancelled? || event.permanently_relocated?

    limit ||= event.max_occurrences || 5
    occurrence_status = event.default_to_cancelled? ? 'cancelled' : 'active'

    if event.recurrence_type == 'once'
      occ = find_or_create_occurrence_by_date(event.start_time, occurrence_status)
      occ.save! if occ.changed?
    elsif event.recurrence_rule.present?
      schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
      future_dates = schedule.occurrences_between(
        Time.current.in_time_zone(Time.zone),
        1.year.from_now.in_time_zone(Time.zone)
      ).first(limit)

      future_dates.each do |date|
        occ = find_or_create_occurrence_by_date(date, occurrence_status)
        occ.save! if occ.changed?
      end
    end
  end

  # Regenerate occurrences (useful after recurrence rule changes)
  # Updates occurrences in place to preserve URLs/slugs
  def regenerate_future!
    return if event.permanently_cancelled? || event.permanently_relocated?

    scheduled_dates = future_scheduled_dates
    existing_future = event.occurrences.where('occurs_at > ?', Time.current)
    existing_by_date = existing_future.index_by { |occ| occ.occurs_at.in_time_zone(Time.zone).to_date }
    scheduled_date_set = scheduled_dates.to_set { |d| d.in_time_zone(Time.zone).to_date }

    occurrence_status = event.default_to_cancelled? ? 'cancelled' : 'active'
    scheduled_dates.each do |scheduled_time|
      scheduled_date = scheduled_time.in_time_zone(Time.zone).to_date
      existing = existing_by_date[scheduled_date]

      if existing
        update_occurrence_time_if_needed(existing, scheduled_time)
      else
        event.occurrences.create!(occurs_at: scheduled_time, status: occurrence_status)
      end
    end

    # Remove occurrences that are no longer scheduled (only active ones)
    existing_by_date.each do |date, occ|
      next if scheduled_date_set.include?(date)
      next unless occ.status == 'active'

      occ.destroy
    end
  end

  # Get future scheduled dates based on recurrence rule
  def future_scheduled_dates
    limit = event.max_occurrences || 5

    if event.recurrence_type == 'once'
      event.start_time > Time.current ? [event.start_time] : []
    elsif event.recurrence_rule.present?
      schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
      schedule.occurrences_between(
        Time.current.in_time_zone(Time.zone),
        1.year.from_now.in_time_zone(Time.zone)
      ).first(limit)
    else
      []
    end
  end

  # Find existing occurrence by date (ignoring time) or create new one
  # If existing occurrence has wrong time, update it to the correct time
  def find_or_create_occurrence_by_date(scheduled_time, default_status)
    canonical_time = canonicalize_time(scheduled_time)
    scheduled_date = canonical_time.to_date

    day_start = scheduled_date.beginning_of_day
    day_end = scheduled_date.end_of_day
    candidates = event.occurrences.where(occurs_at: (day_start - 1.day)..(day_end + 1.day))
    existing = candidates.find { |occ| occ.occurs_at.in_time_zone(Time.zone).to_date == scheduled_date }

    if existing
      existing.occurs_at = canonical_time if existing.occurs_at.utc != canonical_time.utc
      existing
    else
      event.occurrences.build(occurs_at: canonical_time, status: default_status)
    end
  end

  # Update an occurrence's time if it doesn't match the scheduled time
  def update_occurrence_time_if_needed(occurrence, scheduled_time)
    canonical_time = canonicalize_time(scheduled_time)
    return if occurrence.occurs_at.utc == canonical_time.utc

    occurrence.update_column(:occurs_at, canonical_time) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  # Canonicalize: extract wall-clock components from IceCube's time and re-anchor
  # to the correct DST offset for that date. This prevents PST-offset times from
  # being stored for dates that fall in PDT (and vice versa).
  def canonicalize_time(scheduled_time)
    local = scheduled_time.in_time_zone(Time.zone)
    Time.zone.local(local.year, local.month, local.day, local.hour, local.min, local.sec)
  end
end
