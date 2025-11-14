class HomeController < ApplicationController
  def index
    @site_config = SiteConfig.current

    # Show upcoming occurrences instead of events (better for recurring events)
    @upcoming_occurrences = EventOccurrence
                            .joins(:event)
                            .where(event: policy_scope(Event))
                            .where(events: { status: 'active' })
                            .where(event_occurrences: { status: 'active' })
                            .upcoming
                            .includes(event: %i[hosts user location], banner_image_attachment: :blob)
                            .limit(6)

    # Get unique events from occurrences for display
    @upcoming_events = @upcoming_occurrences.map(&:event).uniq
  end
end
