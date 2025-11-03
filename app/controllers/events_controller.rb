class EventsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:ical]
  
  before_action :authenticate_user!, except: %i[index show ical]
  before_action :set_event, only: %i[show edit update destroy postpone cancel reactivate ical]
  before_action :authorize_event, only: %i[edit update destroy postpone cancel reactivate]

  def index
    @events = policy_scope(Event).includes(:user, :hosts).order(start_time: :asc)

    respond_to do |format|
      format.html
      format.json do
        # For JSON, only return public events with upcoming occurrences
        public_events = Event.public_events
                             .active
                             .includes(:hosts, :occurrences, banner_image_attachment: :blob)
                             .order(start_time: :asc)

        events_data = public_events.map do |event|
          {
            id: event.id,
            title: event.title,
            description: event.description,
            status: event.status,
            start_time: event.start_time.iso8601,
            duration: event.duration,
            recurrence_type: event.recurrence_type,
            more_info_url: event.more_info_url,
            hosts: event.hosts.map { |h| h.name || h.email },
            banner_url: event.banner_image.attached? ? url_for(event.banner_image) : nil,
            occurrences: event.occurrences.upcoming.limit(event.max_occurrences || 5).map do |occ|
              {
                id: occ.id,
                occurs_at: occ.occurs_at.iso8601,
                status: occ.status,
                duration: occ.duration,
                description: occ.description,
                postponed_until: occ.postponed_until&.iso8601,
                cancellation_reason: occ.cancellation_reason,
                banner_url: occ.banner.attached? ? url_for(occ.banner) : nil,
                has_custom_banner: occ.banner_image.attached?
              }
            end
          }
        end

        render json: {
          events: events_data,
          generated_at: Time.now.iso8601,
          count: events_data.count
        }
      end
    end
  end

  def show
    authorize @event
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
      redirect_to @event, notice: 'Event was successfully created.'
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

    # Rebuild schedule if recurrence changed
    if params[:event][:recurrence_type].present? && @event.recurring?
      recurrence_params = build_recurrence_params
      schedule = Event.build_schedule(@event.start_time, params[:event][:recurrence_type], recurrence_params)
      @event.recurrence_rule = schedule.to_yaml
    end

    if @event.update(event_params)
      redirect_to @event, notice: 'Event was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
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

  def ical
    @event = Event.find_by!(ical_token: params[:token])

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
    @event = Event.find(params[:id])
  end

  def authorize_event
    authorize @event
  end

  def event_params
    params.require(:event).permit(:title, :description, :start_time, :duration,
                                  :recurrence_type, :status, :visibility, :open_to,
                                  :more_info_url, :max_occurrences, :banner_image, :remove_banner_image)
  end

  def build_recurrence_params
    {
      days: params[:recurrence_days]&.map(&:to_i),
      occurrence: params[:recurrence_occurrence],
      day: params[:recurrence_day]
    }.compact
  end
end
