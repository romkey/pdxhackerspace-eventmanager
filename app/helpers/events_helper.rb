module EventsHelper
  def parse_monthly_recurrence(event)
    # Return empty if not a monthly event or no recurrence rule
    return { occurrences: [], day: nil } unless event.persisted? && event.recurrence_type == 'monthly' && event.recurrence_rule.present?

    begin
      schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
      rules = schedule.rrules

      return { occurrences: [], day: nil } if rules.empty?

      rule = rules.first
      validations = rule.validations

      # Extract day of week
      day_of_week = validations[:day_of_week]

      if day_of_week.present? && !day_of_week.empty?
        # day_of_week is a hash like { monday: [1, 3] } meaning 1st and 3rd Monday
        day_sym = day_of_week.keys.first
        occurrence_nums = day_of_week[day_sym]

        # Convert numbers to names: 1=first, 2=second, 3=third, 4=fourth, -1=last
        occurrence_map = { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', -1 => 'last' }
        occurrence_names = occurrence_nums.map { |num| occurrence_map[num] }.compact

        { occurrences: occurrence_names, day: day_sym.to_s }
      else
        # No day_of_week validation means it's monthly on same day of month
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
