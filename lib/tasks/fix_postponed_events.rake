namespace :events do
  desc "Fix events that were incorrectly postponed (event-level instead of occurrence-level)"
  task fix_postponed_events: :environment do
    # Find events where event.status = 'postponed' but have active occurrences
    Event.where(status: 'postponed').find_each do |event|
      puts "Checking event: #{event.title} (ID: #{event.id})"
      puts "  Current status: #{event.status}"
      puts "  Postponed until: #{event.postponed_until}"
      puts "  Occurrences: #{event.occurrences.count}"

      # Find the occurrence that should have been postponed
      original_occurrence = event.occurrences.where(status: 'active').first

      if original_occurrence && event.postponed_until.present?
        puts "  Found active occurrence ##{original_occurrence.id} at #{original_occurrence.occurs_at}"
        puts "  This should be postponed to #{event.postponed_until}"

        # Mark the occurrence as postponed
        original_occurrence.update!(
          status: 'postponed',
          postponed_until: event.postponed_until,
          cancellation_reason: event.cancellation_reason
        )
        puts "  ✓ Marked occurrence ##{original_occurrence.id} as postponed"

        # Create new occurrence at the postponed date
        new_occurrence = event.occurrences.create!(
          occurs_at: event.postponed_until,
          status: 'active'
        )
        puts "  ✓ Created new active occurrence ##{new_occurrence.id} at #{new_occurrence.occurs_at}"

        # Reset the event status to active
        event.update!(
          status: 'active',
          postponed_until: nil,
          cancellation_reason: nil
        )
        puts "  ✓ Reset event status to active"
      else
        puts "  No active occurrence found or no postponed_until date set - skipping"
      end
      puts ""
    end

    puts "Done!"
  end
end
