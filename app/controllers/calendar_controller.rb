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
            banner_url: occ.banner.attached? ? url_for(occ.banner) : nil,
            has_custom_banner: occ.banner_image.attached?,
            event: {
              id: occ.event.id,
              title: occ.event.title,
              recurrence_type: occ.event.recurrence_type,
              more_info_url: occ.event.more_info_url,
              visibility: occ.event.visibility,
              open_to: occ.event.open_to,
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
end
