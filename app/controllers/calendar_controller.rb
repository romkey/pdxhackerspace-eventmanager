class CalendarController < ApplicationController
  before_action :allow_iframe, only: :embed

  def index
    @embed = false
    @view = params[:view] || 'calendar' # Default to calendar view
    @current_month = params[:month] ? Date.parse(params[:month]) : Date.current.beginning_of_month
    @open_to_filter = params[:open_to]

    # Get occurrences based on view type
    if @view == 'calendar'
      # For calendar view, get occurrences for the full visible range (includes prev/next month days)
      calendar_start = @current_month.beginning_of_month.beginning_of_week(:sunday)
      calendar_end = @current_month.end_of_month.end_of_week(:sunday)

      @occurrences = if current_user
                       EventOccurrence
                         .joins(:event)
                         .where(event: policy_scope(Event))
                         .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?',
                                calendar_start.beginning_of_day, calendar_end.end_of_day)
                         .where(event_occurrences: { status: %w[active postponed cancelled relocated] })
                         .includes(event: %i[hosts user], banner_image_attachment: :blob)
                         .order(:occurs_at)
                     else
                       EventOccurrence
                         .joins(:event)
                         .where(events: { visibility: 'public', draft: false })
                         .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?',
                                calendar_start.beginning_of_day, calendar_end.end_of_day)
                         .where(event_occurrences: { status: %w[active postponed cancelled relocated] })
                         .includes(event: %i[hosts user], banner_image_attachment: :blob)
                         .order(:occurs_at)
                     end

      # Apply open_to filter if specified
      @occurrences = @occurrences.where(events: { open_to: @open_to_filter }) if @open_to_filter.present?

      # Group by date for calendar view
      @occurrences_by_date = @occurrences.group_by { |occ| occ.occurs_at.to_date }

      Rails.logger.info "Calendar view for #{@current_month.strftime('%B %Y')}: Found #{@occurrences.count} occurrences"
      @occurrences.each do |occ|
        Rails.logger.info "  - Occurrence ##{occ.id}: #{occ.event.title} at #{occ.occurs_at} (status: #{occ.status})"
      end
    else
      # For list view, get occurrences from today forward (all statuses)
      @occurrences = if current_user
                       EventOccurrence
                         .joins(:event)
                         .where(event: policy_scope(Event))
                         .where('event_occurrences.occurs_at >= ?', Time.current.beginning_of_day)
                         .where(event_occurrences: { status: %w[active postponed cancelled relocated] })
                         .includes(event: %i[hosts user], banner_image_attachment: :blob)
                         .order(:occurs_at)
                         .limit(50)
                     else
                       EventOccurrence
                         .joins(:event)
                         .where(events: { visibility: 'public', draft: false })
                         .where('event_occurrences.occurs_at >= ?', Time.current.beginning_of_day)
                         .where(event_occurrences: { status: %w[active postponed cancelled relocated] })
                         .includes(event: %i[hosts user], banner_image_attachment: :blob)
                         .order(:occurs_at)
                         .limit(50)
                     end

      # Apply open_to filter if specified
      @occurrences = @occurrences.where(events: { open_to: @open_to_filter }) if @open_to_filter.present?

      # Group by month for list view
      @occurrences_by_month = @occurrences.group_by { |occ| occ.occurs_at.beginning_of_month }
    end

    respond_to do |format|
      format.html
      format.json { render json: calendar_json_response }
    end
  end

  def embed
    # Same logic as index but with embed layout
    @view = params[:view] || 'calendar' # Default to calendar view
    @current_month = params[:month] ? Date.parse(params[:month]) : Date.current.beginning_of_month
    @open_to_filter = params[:open_to]

    # Get occurrences based on view type (public events only for embeds)
    if @view == 'calendar'
      # For calendar view, get occurrences for the full visible range (includes prev/next month days)
      calendar_start = @current_month.beginning_of_month.beginning_of_week(:sunday)
      calendar_end = @current_month.end_of_month.end_of_week(:sunday)

      @occurrences = EventOccurrence
                     .joins(:event)
                     .where(events: { visibility: 'public', draft: false })
                     .where('event_occurrences.occurs_at >= ? AND event_occurrences.occurs_at <= ?',
                            calendar_start.beginning_of_day, calendar_end.end_of_day)
                     .where(event_occurrences: { status: %w[active postponed cancelled relocated] })
                     .includes(event: %i[hosts user], banner_image_attachment: :blob)
                     .order(:occurs_at)

      # Apply open_to filter if specified
      @occurrences = @occurrences.where(events: { open_to: @open_to_filter }) if @open_to_filter.present?

      @occurrences_by_date = @occurrences.group_by { |occ| occ.occurs_at.to_date }
    else
      # For list view, get occurrences from today forward (all statuses)
      @occurrences = EventOccurrence
                     .joins(:event)
                     .where(events: { visibility: 'public', draft: false })
                     .where('event_occurrences.occurs_at >= ?', Time.current.beginning_of_day)
                     .where(event_occurrences: { status: %w[active postponed cancelled relocated] })
                     .includes(event: %i[hosts user], banner_image_attachment: :blob)
                     .order(:occurs_at)
                     .limit(50)

      # Apply open_to filter if specified
      @occurrences = @occurrences.where(events: { open_to: @open_to_filter }) if @open_to_filter.present?

      @occurrences_by_month = @occurrences.group_by { |occ| occ.occurs_at.beginning_of_month }
    end

    @embed = true
    render layout: 'embed'
  end

  def ical
    # Get all public event occurrences (next 6 months)
    six_months_from_now = 6.months.from_now
    @occurrences = EventOccurrence
                   .joins(:event)
                   .where(events: { visibility: 'public', status: 'active', draft: false })
                   .where('event_occurrences.occurs_at >= ?', Time.current)
                   .where('event_occurrences.occurs_at <= ?', six_months_from_now)
                   .where(event_occurrences: { status: 'active' })
                   .includes(event: %i[location hosts user])
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

  private

  def allow_iframe
    response.headers.delete('X-Frame-Options')
  end

  def calendar_json_response
    now = Time.current
    public_occurrences = EventOccurrence
                         .joins(:event)
                         .where(events: { visibility: 'public', draft: false })
                         .includes(event: [:hosts, { banner_image_attachment: :blob }], banner_image_attachment: :blob)
                         .order(:occurs_at)
                         .limit(100)

    occurrences_data = public_occurrences.filter_map do |occ|
      build_calendar_occurrence_json(occ, now)
    end

    {
      occurrences: occurrences_data,
      generated_at: Time.current.iso8601,
      count: occurrences_data.count
    }
  end

  def build_calendar_occurrence_json(occ, now)
    occurrence_end = occ.occurs_at + occ.duration.minutes
    return nil if occurrence_end < now

    {
      id: occ.id,
      slug: occ.slug,
      occurs_at: occ.occurs_at.iso8601,
      status: occ.status,
      duration: occ.duration,
      description: occ.description,
      postponed_until: occ.postponed_until&.iso8601,
      cancellation_reason: occ.cancellation_reason,
      relocated_to: occ.relocated_to,
      in_progress: now >= occ.occurs_at && now < occurrence_end,
      open_to: occ.event.open_to,
      location: occ.event_location ? { id: occ.event_location.id, name: occ.event_location.name } : nil,
      has_custom_location: occ.location_id.present?,
      banner_url: occ.banner.attached? ? url_for(occ.banner) : nil,
      has_custom_banner: occ.banner_image.attached?,
      event: build_calendar_event_info(occ.event)
    }
  end

  def build_calendar_event_info(event)
    {
      id: event.id,
      slug: event.slug,
      title: event.title,
      recurrence_type: event.recurrence_type,
      more_info_url: event.more_info_url,
      visibility: event.visibility,
      open_to: event.open_to,
      location: event.location ? { id: event.location.id, name: event.location.name } : nil,
      hosts: event.hosts.map { |h| h.name || h.email }
    }
  end
end
