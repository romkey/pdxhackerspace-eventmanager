# frozen_string_literal: true

module EventsHelper
  DAY_NUM_TO_NAME = { 0 => 'sunday', 1 => 'monday', 2 => 'tuesday', 3 => 'wednesday',
                      4 => 'thursday', 5 => 'friday', 6 => 'saturday' }.freeze
  OCC_NUM_TO_NAME = { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', -1 => 'last' }.freeze

  def schedule_description(event)
    case event.recurrence_type
    when 'once' then event.start_time.strftime('%A, %B %d, %Y')
    when 'weekly' then weekly_schedule_description(event)
    when 'monthly' then monthly_schedule_description(event)
    else event.recurrence_type.titleize
    end
  end

  def parse_monthly_recurrence(event)
    return { occurrences: [], day: nil } unless event.persisted? && event.recurrence_type == 'monthly' &&
                                                event.recurrence_rule.present?

    parse_monthly_rule(event)
  rescue StandardError => e
    Rails.logger.error "Error parsing monthly recurrence for event #{event.id}: #{e.message}"
    { occurrences: [], day: nil }
  end

  def parse_weekly_recurrence(event)
    return [] unless event.persisted? && event.recurrence_type == 'weekly' && event.recurrence_rule.present?

    parse_weekly_rule(event)
  rescue StandardError => e
    Rails.logger.error "Error parsing weekly recurrence for event #{event.id}: #{e.message}"
    []
  end

  private

  def parse_monthly_rule(event)
    rules = IceCube::Schedule.from_yaml(event.recurrence_rule).rrules
    return { occurrences: [], day: nil } if rules.empty?

    raw_day_of_week = rules.first.validations[:day_of_week]
    return { occurrences: [], day: nil } if raw_day_of_week.blank?

    day_num = nil
    occurrence_nums = []
    raw_day_of_week.each do |validation|
      day_num ||= validation.day if validation.respond_to?(:day)
      occ = validation.instance_variable_get(:@occ)
      occurrence_nums << occ if occ
    end

    return { occurrences: [], day: nil } unless day_num && occurrence_nums.any?

    { occurrences: occurrence_nums.map { |num| OCC_NUM_TO_NAME[num] }.compact, day: DAY_NUM_TO_NAME[day_num] }
  end

  def parse_weekly_rule(event)
    rules = IceCube::Schedule.from_yaml(event.recurrence_rule).rrules
    return [] if rules.empty?

    day_validations = rules.first.validations[:day] || []
    # Extract day numbers from validation objects
    day_validations.map { |v| v.respond_to?(:day) ? v.day : v }.compact
  end

  def weekly_schedule_description(event)
    days = parse_weekly_recurrence(event)
    return "Weekly on #{event.start_time.strftime('%A')}" if days.empty?

    day_names = days.map { |d| Date::DAYNAMES[d] }
    day_names.length == 1 ? "Weekly on #{day_names.first}" : "Weekly on #{format_list(day_names)}"
  end

  def monthly_schedule_description(event)
    parsed = parse_monthly_recurrence(event)
    return monthly_day_of_month_description(event) unless parsed[:day].present? && parsed[:occurrences].any?

    day_name = parsed[:day].titleize
    occ_names = parsed[:occurrences].map(&:titleize)
    occ_names.length == 1 ? "#{occ_names.first} #{day_name}s" : "#{format_list(occ_names)} #{day_name}s"
  end

  def monthly_day_of_month_description(event)
    day = event.start_time.day
    suffix = (11..13).include?(day % 100) ? 'th' : { 1 => 'st', 2 => 'nd', 3 => 'rd' }.fetch(day % 10, 'th')
    "#{day}#{suffix} of each month"
  end

  def format_list(items)
    "#{items[0..-2].join(', ')} and #{items.last}"
  end
end
