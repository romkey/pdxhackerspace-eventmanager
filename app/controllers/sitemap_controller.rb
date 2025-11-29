class SitemapController < ApplicationController
  def index
    @events = Event.where(status: 'active', draft: false)
                   .where(visibility: %w[public members])
                   .includes(:occurrences)
                   .order(updated_at: :desc)

    @occurrences = EventOccurrence.joins(:event)
                                  .where(events: { status: 'active', draft: false })
                                  .where(events: { visibility: %w[public members] })
                                  .where('event_occurrences.occurs_at >= ?', Date.current)
                                  .order(occurs_at: :asc)
                                  .limit(500)

    respond_to do |format|
      format.xml
    end
  end
end
