class EventOccurrencesController < ApplicationController
  include ReminderMessageBuilder

  before_action :set_occurrence, only: %i[show edit update destroy postpone cancel reactivate]
  before_action :authorize_occurrence, only: %i[edit update destroy postpone cancel reactivate]

  before_action :authorize_occurrence, only: %i[post_slack_reminder post_social_reminder]
  before_action :set_occurrence, only: %i[post_slack_reminder post_social_reminder]

  def show
    unless @occurrence&.event
      redirect_back(fallback_location: events_path, alert: 'Event not found.')
      return
    end

    @event = @occurrence.event
  end

  def edit
    unless @occurrence&.event
      redirect_back(fallback_location: events_path, alert: 'Event not found.')
      return
    end

    @event = @occurrence.event
  end

  def update
    @occurrence.current_user_for_journal = current_user

    # Handle banner image removal
    if params[:event_occurrence][:remove_banner_image] == '1'
      EventJournal.log_occurrence_change(
        @occurrence,
        current_user,
        'banner_removed',
        { 'banner_image' => { 'action' => 'removed' } }
      )
      @occurrence.banner_image.purge
    end

    if @occurrence.update(occurrence_params)
      redirect_to @occurrence, notice: 'Occurrence was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event = @occurrence.event
    @occurrence.destroy
    redirect_to @event, notice: 'Occurrence was successfully deleted.'
  end

  def postpone
    postponed_until = params[:postponed_until] ? Time.parse(params[:postponed_until]) : 1.week.from_now
    if @occurrence.postpone!(postponed_until, params[:reason], current_user)
      redirect_back fallback_location: @occurrence.event, notice: 'Occurrence was postponed. A new occurrence has been created at the rescheduled date.'
    else
      redirect_back fallback_location: @occurrence, alert: 'Failed to postpone occurrence.'
    end
  end

  def cancel
    if @occurrence.cancel!(params[:reason], current_user)
      redirect_to @occurrence, notice: 'Occurrence was cancelled.'
    else
      redirect_to @occurrence, alert: 'Failed to cancel occurrence.'
    end
  end

  def reactivate
    if @occurrence.reactivate!(current_user)
      redirect_to @occurrence, notice: 'Occurrence was reactivated.'
    else
      redirect_to @occurrence, alert: 'Failed to reactivate occurrence.'
    end
  end

  def post_slack_reminder
    site_config = SiteConfig.current
    unless site_config.slack_enabled? && @occurrence.event.slack_announce?
      redirect_to @occurrence, alert: 'Slack reminders are disabled for this occurrence.'
      return
    end

    message = reminder_message(@occurrence, 'today')
    if SlackService.post_message(message)
      redirect_to @occurrence, notice: 'Posted reminder to Slack.'
    else
      redirect_to @occurrence, alert: 'Failed to post to Slack.'
    end
  end

  def post_social_reminder
    site_config = SiteConfig.current
    unless site_config.social_reminders_enabled? && @occurrence.event.social_reminders?
      redirect_to @occurrence, alert: 'Social reminders are disabled for this occurrence.'
      return
    end

    message = reminder_message(@occurrence, 'today')
    success_instagram = SocialService.post_instagram(message)
    success_bluesky = SocialService.post_bluesky(message)

    if success_instagram || success_bluesky
      redirect_to @occurrence, notice: 'Posted reminder to social media.'
    else
      redirect_to @occurrence, alert: 'Failed to post to social media.'
    end
  end

  private

  def set_occurrence
    @occurrence = EventOccurrence.find(params[:id])
  end

  def authorize_occurrence
    @event = @occurrence.event
    return if current_user && (current_user.admin? || @event.hosted_by?(current_user))

    redirect_to @occurrence, alert: "You are not authorized to manage this occurrence."
  end

  def occurrence_params
    params.require(:event_occurrence).permit(:custom_description, :duration_override, :status, :banner_image,
                                             :remove_banner_image, :location_id, :ai_reminder_7d, :ai_reminder_1d)
  end
end
