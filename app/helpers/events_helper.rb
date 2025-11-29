# frozen_string_literal: true

module EventsHelper
  # Day number to name mapping for IceCube
  DAY_NUM_TO_NAME = { 0 => 'sunday', 1 => 'monday', 2 => 'tuesday', 3 => 'wednesday',
                      4 => 'thursday', 5 => 'friday', 6 => 'saturday' }.freeze

  # Occurrence number to name mapping
  OCC_NUM_TO_NAME = { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', -1 => 'last' }.freeze

  def parse_monthly_recurrence(event)
    return { occurrences: [], day: nil } unless valid_monthly_event?(event)

    parse_monthly_rule(event)
  rescue StandardError => e
    Rails.logger.error "Error parsing monthly recurrence for event #{event.id}: #{e.message}"
    { occurrences: [], day: nil }
  end

  def parse_weekly_recurrence(event)
    return [] unless valid_weekly_event?(event)

    parse_weekly_rule(event)
  rescue StandardError => e
    Rails.logger.error "Error parsing weekly recurrence for event #{event.id}: #{e.message}"
    []
  end

  private

  def valid_monthly_event?(event)
    event.persisted? && event.recurrence_type == 'monthly' && event.recurrence_rule.present?
  end

  def valid_weekly_event?(event)
    event.persisted? && event.recurrence_type == 'weekly' && event.recurrence_rule.present?
  end

  def parse_monthly_rule(event)
    schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
    rules = schedule.rrules
    return { occurrences: [], day: nil } if rules.empty?

    extract_monthly_validations(rules.first)
  end

  def extract_monthly_validations(rule)
    raw_day_of_week = rule.validations[:day_of_week]
    return { occurrences: [], day: nil } if raw_day_of_week.blank?

    day_num, occurrence_nums = extract_day_and_occurrences(raw_day_of_week)
    build_monthly_result(day_num, occurrence_nums)
  end

  def extract_day_and_occurrences(raw_day_of_week)
    day_num = nil
    occurrence_nums = []

    raw_day_of_week.each do |validation|
      day_num ||= validation.day if validation.respond_to?(:day)
      occ = validation.instance_variable_get(:@occ)
      occurrence_nums << occ if occ
    end

    [day_num, occurrence_nums]
  end

  def build_monthly_result(day_num, occurrence_nums)
    if day_num && occurrence_nums.any?
      day_name = DAY_NUM_TO_NAME[day_num]
      occurrence_names = occurrence_nums.map { |num| OCC_NUM_TO_NAME[num] }.compact
      { occurrences: occurrence_names, day: day_name }
    else
      { occurrences: [], day: nil }
    end
  end

  def parse_weekly_rule(event)
    schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
    rules = schedule.rrules
    return [] if rules.empty?

    rule = rules.first
    rule.validations[:day] || []
  end
end
