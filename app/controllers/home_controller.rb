class HomeController < ApplicationController
  def index
    @site_config = SiteConfig.current

    # Show ALL upcoming occurrences (no limit) in chronological order
    @upcoming_occurrences = EventOccurrence
                            .joins(:event)
                            .where(event: policy_scope(Event))
                            .where(events: { status: 'active' })
                            .where(event_occurrences: { status: 'active' })
                            .upcoming
                            .includes(event: %i[hosts user location], banner_image_attachment: :blob)

    # Build a map of event_id => next occurrence for display
    @next_occurrence_by_event = {}
    @upcoming_occurrences.each do |occurrence|
      event_id = occurrence.event_id
      next if @next_occurrence_by_event[event_id] # Already have the first (earliest) occurrence

      @next_occurrence_by_event[event_id] = occurrence
    end

    # Get unique events from occurrences, sorted by next occurrence date
    @upcoming_events = @upcoming_occurrences.map(&:event).uniq.sort_by do |event|
      @next_occurrence_by_event[event.id]&.occurs_at || event.start_time
    end
  end
end
