# Helper module for DST occurrence fixing
module DstOccurrenceFixer
  module_function

  def fix_event(event)
    puts "Processing: #{event.title} (ID: #{event.id})"

    schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
    expected_hour = schedule.start_time.in_time_zone(Time.zone).hour
    expected_min = schedule.start_time.in_time_zone(Time.zone).min
    puts "  Expected time: #{format('%<hour>02d:%<min>02d', hour: expected_hour, min: expected_min)} local"

    # Get ALL future occurrences, not just ones matching schedule dates
    existing_future = event.occurrences.where('occurs_at > ?', Time.current)
    puts "  Found #{existing_future.count} future occurrences"

    updated_count = 0
    existing_future.find_each do |occ|
      local_time = occ.occurs_at.in_time_zone(Time.zone)
      current_hour = local_time.hour
      current_min = local_time.min

      # Check if the time is off (typically by 1 hour for DST)
      if current_hour != expected_hour || current_min != expected_min
        # Build the correct time: same date, correct hour/minute
        correct_time = local_time.change(hour: expected_hour, min: expected_min)

        puts "  Fixing ##{occ.id}: #{local_time.strftime('%Y-%m-%d %H:%M')} -> #{correct_time.strftime('%H:%M')}"
        # rubocop:disable Rails/SkipsModelValidations
        occ.update_column(:occurs_at, correct_time)
        # rubocop:enable Rails/SkipsModelValidations
        updated_count += 1
      end
    end

    puts "  Updated #{updated_count} occurrences"
    puts ""
  rescue StandardError => e
    puts "  ERROR: #{e.message}"
    puts "  #{e.backtrace.first(3).join("\n  ")}"
    puts ""
  end

  def regenerate_event(event)
    puts "Processing: #{event.title} (ID: #{event.id})"
    event.regenerate_future_occurrences!
    puts "  Regenerated successfully"
  rescue StandardError => e
    puts "  ERROR: #{e.message}"
  end

  def debug_events
    puts "Debugging DST occurrence times..."
    puts "Time zone: #{Time.zone.name}"
    puts "Current time: #{Time.current}"
    puts ""

    Event.where.not(recurrence_rule: nil).limit(5).each do |event|
      debug_single_event(event)
    end
  end

  def debug_single_event(event)
    puts "Event: #{event.title} (ID: #{event.id})"

    schedule = IceCube::Schedule.from_yaml(event.recurrence_rule)
    puts "  Schedule start: #{schedule.start_time.inspect}"
    puts "  Schedule start (local): #{schedule.start_time.in_time_zone(Time.zone)}"

    puts "  Future occurrences in DB:"
    event.occurrences.where('occurs_at > ?', Time.current).limit(3).each do |occ|
      local = occ.occurs_at.in_time_zone(Time.zone)
      puts "    ##{occ.id}: #{occ.occurs_at} (UTC) = #{local} (local)"
    end

    puts "  IceCube generates:"
    schedule.occurrences_between(Time.current, 3.months.from_now).first(3).each do |d|
      puts "    #{d.inspect} = #{d.in_time_zone(Time.zone)} (local)"
    end

    puts ""
  end
end

namespace :events do
  desc 'Fix occurrence times for DST by adjusting to match schedule start time'
  task fix_dst_occurrences: :environment do
    puts "Fixing DST occurrence times..."
    puts "Time zone: #{Time.zone.name}"
    puts "Current time: #{Time.current}"
    puts ""

    Event.where.not(recurrence_rule: nil).find_each do |event|
      DstOccurrenceFixer.fix_event(event)
    end

    puts "Done!"
  end

  desc 'Regenerate all future occurrences for all events (destructive for active occurrences)'
  task regenerate_all_occurrences: :environment do
    puts "Regenerating all future occurrences..."
    puts "Time zone: #{Time.zone.name}"
    puts ""

    Event.active.not_permanently_cancelled.not_permanently_relocated.find_each do |event|
      DstOccurrenceFixer.regenerate_event(event)
    end

    puts "Done!"
  end

  desc 'Show occurrence times for debugging DST issues'
  task debug_dst: :environment do
    DstOccurrenceFixer.debug_events
  end
end
