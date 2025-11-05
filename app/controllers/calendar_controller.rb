class CalendarController < ApplicationController
  def index
    # Get all upcoming occurrences for events the user can see
    @occurrences = if current_user
                     # Signed in users see occurrences based on event visibility
                     EventOccurrence
                       .joins(:event)
                       .where(event: policy_scope(Event))
                       .upcoming
                       .includes(event: [:hosts, :user,
                                         { banner_image_attachment: :blob }], banner_image_attachment: :blob)
                       .limit(50)
                   else
                     # Public users only see public event occurrences
                     EventOccurrence
                       .joins(:event)
                       .where(events: { visibility: 'public' })
                       .upcoming
                       .includes(event: [:hosts, :user,
                                         { banner_image_attachment: :blob }], banner_image_attachment: :blob)
                       .limit(50)
                   end

    # Group by month for display
    @occurrences_by_month = @occurrences.group_by { |occ| occ.occurs_at.beginning_of_month }

    respond_to do |format|
      format.html
      format.json do
        # For JSON, only return public event occurrences
        public_occurrences = EventOccurrence
                             .joins(:event)
                             .where(events: { visibility: 'public' })
                             .upcoming
                             .includes(event: [:hosts,
                                               { banner_image_attachment: :blob }], banner_image_attachment: :blob)
                             .limit(100)

        occurrences_data = public_occurrences.map do |occ|
          {
            id: occ.id,
            occurs_at: occ.occurs_at.iso8601,
            status: occ.status,
            duration: occ.duration,
            description: occ.description,
            postponed_until: occ.postponed_until&.iso8601,
            cancellation_reason: occ.cancellation_reason,
            location: occ.event_location ? { id: occ.event_location.id, name: occ.event_location.name } : nil,
            has_custom_location: occ.location_id.present?,
            banner_url: occ.banner.attached? ? url_for(occ.banner) : nil,
            has_custom_banner: occ.banner_image.attached?,
            event: {
              id: occ.event.id,
              title: occ.event.title,
              recurrence_type: occ.event.recurrence_type,
              more_info_url: occ.event.more_info_url,
              visibility: occ.event.visibility,
              open_to: occ.event.open_to,
              location: occ.event.location ? { id: occ.event.location.id, name: occ.event.location.name } : nil,
              hosts: occ.event.hosts.map { |h| h.name || h.email }
            }
          }
        end

        render json: {
          occurrences: occurrences_data,
          generated_at: Time.now.iso8601,
          count: occurrences_data.count
        }
      end
    end
  end

  def ical
    # Get all public event occurrences (next 6 months)
    six_months_from_now = 6.months.from_now
    @occurrences = EventOccurrence
                   .joins(:event)
                   .where(events: { visibility: 'public', status: 'active' })
                   .where('event_occurrences.occurs_at >= ?', Time.current)
                   .where('event_occurrences.occurs_at <= ?', six_months_from_now)
                   .where(event_occurrences: { status: 'active' })
                   .includes(event: [:location, :hosts, :user])
                   .order(:occurs_at)
                   .limit(500)

    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//#{@site_config&.organization_name || 'EventManager'}//Calendar//EN"

    @occurrences.each do |occurrence|
      calendar.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new(occurrence.occurs_at)
        e.dtend = Icalendar::Values::DateTime.new(occurrence.occurs_at + occurrence.duration.minutes)
        e.summary = occurrence.event.title
        e.description = occurrence.description
        e.url = event_url(occurrence.event)

        # Add location if present
        e.location = occurrence.event_location.name if occurrence.event_location

        # Add organizer/hosts
        if occurrence.event.hosts.any?
          host_names = occurrence.event.hosts.map { |h| h.name || h.email }.join(', ')
          e.organizer = "Hosts: #{host_names}"
        end

        # Unique identifier for this occurrence
        e.uid = "occurrence-#{occurrence.id}@#{request.host}"
        e.dtstamp = Icalendar::Values::DateTime.new(occurrence.updated_at)
      end
    end

    calendar.publish

    respond_to do |format|
      format.ics { render plain: calendar.to_ical, content_type: 'text/calendar' }
    end
  end
end
