class EventsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:ical]

  before_action :authenticate_user!, except: %i[index show ical embed rss event_rss]
  before_action :set_event, only: %i[show embed edit update destroy postpone cancel reactivate generate_ai_reminder event_rss]
  before_action :authorize_event, only: %i[edit update destroy postpone cancel reactivate]

  def index
    @search_query = params[:q]

    # Start with policy-scoped events
    base_events = policy_scope(Event).where(status: 'active')

    # Apply search filter if query present
    base_events = base_events.search(@search_query) if @search_query.present?

    # Get upcoming occurrences for these events
    upcoming_occurrences = EventOccurrence
                           .joins(:event)
                           .where(event: base_events)
                           .where(event_occurrences: { status: 'active' })
                           .upcoming
                           .includes(event: %i[user hosts])

    # Build a map of event_id => next occurrence for display
    @next_occurrence_by_event = {}
    upcoming_occurrences.each do |occurrence|
      event_id = occurrence.event_id
      next if @next_occurrence_by_event[event_id] # Already have the first (earliest) occurrence

      @next_occurrence_by_event[event_id] = occurrence
    end

    # Get unique events, sorted by next occurrence date
    @events = upcoming_occurrences.map(&:event).uniq.sort_by do |event|
      @next_occurrence_by_event[event.id]&.occurs_at || event.start_time
    end

    respond_to do |format|
      format.html
      format.json { render json: events_json_response }
    end
  end

  def rss
    @events = Event.where(status: 'active', draft: false)
                   .where(visibility: %w[public members])
                   .includes(:user, :hosts, :occurrences)
                   .order(updated_at: :desc)
                   .limit(50)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  def event_rss
    # RSS feed for a single event's occurrences
    # Only allow for public/members events that aren't drafts
    if @event.draft? || @event.visibility == 'private'
      head :not_found
      return
    end

    @occurrences = @event.occurrences.upcoming.limit(20)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  def show
    authorize @event
  end

  def embed
    # Public embed view for event calendar
    # Don't allow embedding draft events
    if @event.draft?
      head :forbidden
      return
    end

    # Only show for public events or if user is authorized
    unless @event.public? || (current_user && (current_user.admin? || @event.hosted_by?(current_user)))
      head :forbidden
      return
    end

    @view = params[:view] || 'calendar' # Default to calendar view

    if @view == 'calendar'
      # Get occurrences for display in calendar
      @current_month = params[:month] ? Date.parse(params[:month]) : @event.start_time.to_date.beginning_of_month
      month_start = @current_month.beginning_of_month
      month_end = @current_month.end_of_month

      @occurrences = @event.occurrences
                           .where('occurs_at >= ? AND occurs_at <= ?', month_start, month_end)
                           .where(status: %w[active postponed cancelled])
                           .order(:occurs_at)

      @occurrences_by_date = @occurrences.group_by { |occ| occ.occurs_at.to_date }
    else
      # List view
      @occurrences = @event.occurrences
                           .where('occurs_at >= ? OR status IN (?)', Time.now, %w[postponed cancelled])
                           .order(:occurs_at)
                           .limit(50)

      @occurrences_by_month = @occurrences.group_by { |occ| occ.occurs_at.beginning_of_month }
    end

    render layout: 'embed'
  end

  def new
    @event = current_user.events.build
    authorize @event
  end

  def edit; end

  def create
    @event = current_user.events.build(event_params)
    @event.current_user_for_journal = current_user
    authorize @event

    # Build IceCube schedule if recurring
    if @event.recurring?
      recurrence_params = build_recurrence_params
      schedule = Event.build_schedule(@event.start_time, @event.recurrence_type, recurrence_params)
      @event.recurrence_rule = schedule.to_yaml
    end

    if @event.save
      # Check for scheduling conflicts
      conflicts = @event.check_conflicts

      if conflicts.any?
        # Build conflict warning message
        conflict_links = conflicts.map do |conflict|
          event = conflict[:event]
          occ = conflict[:occurrence]
          location_text = event.location ? " at #{event.location.name}" : ""

          view_context.link_to(
            "#{event.title} (#{occ.occurs_at.strftime('%B %d at %I:%M %p')}#{location_text})",
            view_context.event_path(event),
            class: 'text-white text-decoration-underline'
          )
        end

        flash[:conflict] = view_context.safe_join(
          ['Event created successfully, but scheduling conflicts detected with:', view_context.tag.br] + conflict_links,
          view_context.tag.br
        )
        redirect_to @event
      else
        redirect_to @event, notice: 'Event was successfully created.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @event.current_user_for_journal = current_user

    # Handle banner image removal
    if params[:event][:remove_banner_image] == '1'
      EventJournal.log_event_change(
        @event,
        current_user,
        'banner_removed',
        { 'banner_image' => { 'action' => 'removed' } }
      )
      @event.banner_image.purge
    end

    # Only rebuild schedule if recurrence settings were explicitly changed
    if should_rebuild_schedule?
      recurrence_params = build_recurrence_params
      new_start_time = params[:event][:start_time].present? ? Time.parse(params[:event][:start_time]) : @event.start_time
      schedule = Event.build_schedule(new_start_time, params[:event][:recurrence_type], recurrence_params)
      @event.recurrence_rule = schedule.to_yaml
    end

    begin
      if @event.update(event_params)
        redirect_to @event, notice: 'Event was successfully updated.'
      else
        Rails.logger.error "Event update failed. Errors: #{@event.errors.full_messages.join(', ')}"
        Rails.logger.error "Event attributes: #{@event.attributes.slice('id', 'title', 'status', 'recurrence_type')}"
        render :edit, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Event update exception: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      raise
    end
  end

  def destroy
    @event.destroy
    redirect_to events_url, notice: 'Event was successfully deleted.'
  end

  def postpone
    authorize @event, :postpone?
    postponed_until = params[:postponed_until] ? Time.parse(params[:postponed_until]) : 1.week.from_now
    if @event.postpone!(postponed_until, params[:reason])
      redirect_to @event, notice: 'Event was postponed.'
    else
      redirect_to @event, alert: 'Failed to postpone event.'
    end
  end

  def cancel
    authorize @event, :cancel?
    if @event.cancel!(params[:reason])
      redirect_to @event, notice: 'Event was cancelled.'
    else
      redirect_to @event, alert: 'Failed to cancel event.'
    end
  end

  def reactivate
    authorize @event, :reactivate?
    if @event.reactivate!
      redirect_to @event, notice: 'Event was reactivated.'
    else
      redirect_to @event, alert: 'Failed to reactivate event.'
    end
  end

  def generate_ai_reminder
    authorize @event, :update?

    unless OllamaService.configured?
      render json: { success: false, message: 'AI generation is not configured.' }, status: :service_unavailable
      return
    end

    days = params[:days].to_i
    days = 7 unless [1, 7].include?(days)
    message_type = params[:type] == 'long' ? :long : :short

    message = if message_type == :long
                OllamaService.generate_long_reminder_for_event(@event, days)
              else
                OllamaService.generate_short_reminder_for_event(@event, days)
              end

    if message.present?
      render json: { success: true, message: message }
    else
      render json: { success: false, message: 'AI generation failed. Please try again.' }, status: :unprocessable_entity
    end
  end

  def ical
    @event = Event.find_by!(ical_token: params[:token])

    # Don't include draft events in iCal feeds
    if @event.draft?
      calendar = Icalendar::Calendar.new
      respond_to do |format|
        format.ics { render plain: calendar.to_ical, content_type: 'text/calendar' }
      end
      return
    end

    calendar = Icalendar::Calendar.new

    # Use actual EventOccurrence records (includes status, customizations)
    @event.event_occurrences.upcoming.limit(50).each do |occurrence|
      calendar.event do |e|
        e.dtstart = Icalendar::Values::DateTime.new(occurrence.occurs_at)
        e.dtend = Icalendar::Values::DateTime.new(occurrence.occurs_at + occurrence.duration.minutes)
        e.summary = @event.title
        e.description = occurrence.description # Uses custom or default
        e.status = occurrence.status.upcase # Per-occurrence status

        # Add cancellation reason if present
        e.description += "\n\n#{occurrence.status.titleize}: #{occurrence.cancellation_reason}" if occurrence.cancellation_reason.present?

        # Add postponed info if applicable
        e.description += "\n\nRescheduled to: #{occurrence.postponed_until.strftime('%B %d, %Y at %I:%M %p')}" if occurrence.status == 'postponed' && occurrence.postponed_until
      end
    end

    calendar.publish

    respond_to do |format|
      format.ics { render plain: calendar.to_ical, content_type: 'text/calendar' }
    end
  end

  private

  def set_event
    @event = Event.friendly_find(params[:id])
  end

  def authorize_event
    authorize @event
  end

  def event_params
    params.require(:event).permit(:title, :description, :start_time, :duration,
                                  :recurrence_type, :status, :visibility, :open_to,
                                  :more_info_url, :max_occurrences, :banner_image,
                                  :location_id, :requires_mask, :draft, :slack_announce, :social_reminders,
                                  :reminder_7d_short, :reminder_1d_short, :reminder_7d_long, :reminder_1d_long)
  end

  def build_recurrence_params
    recurrence_type = params[:event][:recurrence_type]
    start_time = params[:event][:start_time].present? ? Time.parse(params[:event][:start_time]) : @event&.start_time

    case recurrence_type
    when 'weekly'
      # For weekly events, automatically use the day of the week from the start date
      { days: [start_time&.wday || 0] }
    when 'monthly'
      # For monthly events, use the form selections
      {
        occurrences: params[:recurrence_occurrences],
        day: params[:recurrence_day]
      }.compact
    else
      {}
    end
  end

  def should_rebuild_schedule?
    return false if params[:event][:recurrence_type].blank?

    # Rebuild if recurrence type changed
    return true if params[:event][:recurrence_type] != @event.recurrence_type

    # Rebuild if start time changed (affects schedule for weekly events)
    return true if params[:event][:start_time].present? && Time.parse(params[:event][:start_time]) != @event.start_time

    # Rebuild if monthly options were explicitly provided
    return true if params[:recurrence_occurrences].present? || params[:recurrence_day].present?

    false
  end

  def events_json_response
    # For JSON, only return published public events with upcoming occurrences
    public_events = Event.published
                         .public_events
                         .active
                         .includes(:hosts, :occurrences, banner_image_attachment: :blob)
                         .order(start_time: :asc)

    events_data = public_events.map do |event|
      {
        id: event.id,
        slug: event.slug,
        title: event.title,
        description: event.description,
        status: event.status,
        start_time: event.start_time.iso8601,
        duration: event.duration,
        recurrence_type: event.recurrence_type,
        more_info_url: event.more_info_url,
        location: event.location ? { id: event.location.id, name: event.location.name, description: event.location.description } : nil,
        hosts: event.hosts.map { |h| h.name || h.email },
        banner_url: event.banner_image.attached? ? url_for(event.banner_image) : nil,
        occurrences: event.occurrences.upcoming.limit(event.max_occurrences || 5).map do |occ|
          {
            id: occ.id,
            slug: occ.slug,
            occurs_at: occ.occurs_at.iso8601,
            status: occ.status,
            duration: occ.duration,
            description: occ.description,
            postponed_until: occ.postponed_until&.iso8601,
            cancellation_reason: occ.cancellation_reason,
            location: occ.event_location ? { id: occ.event_location.id, name: occ.event_location.name } : nil,
            has_custom_location: occ.location_id.present?,
            banner_url: occ.banner.attached? ? url_for(occ.banner) : nil,
            has_custom_banner: occ.banner_image.attached?
          }
        end
      }
    end

    {
      events: events_data,
      generated_at: Time.now.iso8601,
      count: events_data.count
    }
  end
end
