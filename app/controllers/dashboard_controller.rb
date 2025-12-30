class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @site_config = SiteConfig.current

    # Get events where the current user is a host (includes events they created)
    @hosted_events = Event.joins(:event_hosts)
                          .where(event_hosts: { user_id: current_user.id })
                          .includes(:location, :hosts, :event_occurrences)
                          .order(updated_at: :desc)

    # Get upcoming occurrences for hosted events
    @upcoming_occurrences = EventOccurrence
                            .joins(:event)
                            .joins("INNER JOIN event_hosts ON event_hosts.event_id = events.id")
                            .where(event_hosts: { user_id: current_user.id })
                            .where('event_occurrences.occurs_at >= ?', Time.current)
                            .includes(event: %i[hosts location])
                            .order(occurs_at: :asc)
                            .limit(20)
  end
end
