module EventsHelper
  # Day number to name mapping for IceCube
  DAY_NUM_TO_NAME = { 0 => 'sunday', 1 => 'monday', 2 => 'tuesday', 3 => 'wednesday',
                      4 => 'thursday', 5 => 'friday', 6 => 'saturday' }.freeze

  # Occurrence number to name mapping
  OCC_NUM_TO_NAME = { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', -1 => 'last' }.freeze

  def parse_monthly_recurrence(event)
    # Return empty if not a monthly event or no recurrence rule
    return { occurrences: [], day: nil } unless event.persisted? && event.recurrence_type == 'monthly' && event.recurrence_rule.present?

    begin
      schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
      rules = schedule.rrules

      return { occurrences: [], day: nil } if rules.empty?

      rule = rules.first
      validations = rule.validations
      raw_day_of_week = validations[:day_of_week]

      return { occurrences: [], day: nil } if raw_day_of_week.blank?

      # IceCube stores day_of_week validations as an array of Validation objects
      # Each object has @day (0-6 for Sun-Sat) and @occ (1,2,3,4,-1 for first,second,third,fourth,last)
      day_num = nil
      occurrence_nums = []

      raw_day_of_week.each do |validation|
        # Access instance variables directly since there's no public accessor for @occ
        day_num ||= validation.day if validation.respond_to?(:day)
        occ = validation.instance_variable_get(:@occ)
        occurrence_nums << occ if occ
      end

      if day_num && occurrence_nums.any?
        day_name = DAY_NUM_TO_NAME[day_num]
        occurrence_names = occurrence_nums.map { |num| OCC_NUM_TO_NAME[num] }.compact

        { occurrences: occurrence_names, day: day_name }
      else
        { occurrences: [], day: nil }
      end
    rescue StandardError => e
      Rails.logger.error "Error parsing monthly recurrence for event #{event.id}: #{e.message}"
      { occurrences: [], day: nil }
    end
  end

  def parse_weekly_recurrence(event)
    # Return empty if not a weekly event or no recurrence rule
    return [] unless event.persisted? && event.recurrence_type == 'weekly' && event.recurrence_rule.present?

    begin
      schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
      rules = schedule.rrules

      return [] if rules.empty?

      rule = rules.first
      validations = rule.validations

      # Extract days
      days = validations[:day]
      days || []
    rescue StandardError => e
      Rails.logger.error "Error parsing weekly recurrence for event #{event.id}: #{e.message}"
      []
    end
  end
end
