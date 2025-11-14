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

    # Get unique events from occurrences for display
    @upcoming_events = @upcoming_occurrences.map(&:event).uniq
  end
end
