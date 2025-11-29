class EventOccurrencesController < ApplicationController
  include ReminderMessageBuilder

  before_action :set_occurrence, only: %i[show edit update destroy postpone cancel reactivate post_slack_reminder post_social_reminder generate_ai_reminder]
  before_action :authorize_occurrence, only: %i[edit update destroy postpone cancel reactivate post_slack_reminder post_social_reminder generate_ai_reminder]

  def show
    @event = @occurrence.event
  end

  def edit
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
      respond_to do |format|
        format.html { redirect_to @occurrence, alert: 'Slack reminders are disabled for this occurrence.' }
        format.json { render json: { success: false, message: 'Slack reminders are disabled for this occurrence.' } }
      end
      return
    end

    message = reminder_message(@occurrence, 'today')
    if SlackService.post_occurrence_reminder(@occurrence, message)
      respond_to do |format|
        format.html { redirect_to @occurrence, notice: 'Posted reminder to Slack.' }
        format.json { render json: { success: true, message: 'Posted reminder to Slack.' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @occurrence, alert: 'Failed to post to Slack.' }
        format.json { render json: { success: false, message: 'Failed to post to Slack.' } }
      end
    end
  end

  def post_social_reminder
    site_config = SiteConfig.current
    unless site_config.social_reminders_enabled? && @occurrence.event.social_reminders?
      Rails.logger.info "post_social_reminder: Disabled - site=#{site_config.social_reminders_enabled?}, event=#{@occurrence.event.social_reminders?}"
      respond_to do |format|
        format.html { redirect_to @occurrence, alert: 'Social reminders are disabled for this occurrence.' }
        format.json { render json: { success: false, message: 'Social reminders are disabled for this occurrence.' } }
      end
      return
    end

    Rails.logger.info "post_social_reminder: Posting for occurrence #{@occurrence.id} (#{@occurrence.event.title})"
    message = reminder_message(@occurrence, 'today')
    if SocialService.post_occurrence_reminder(@occurrence, message)
      respond_to do |format|
        format.html { redirect_to @occurrence, notice: 'Posted reminder to social media.' }
        format.json { render json: { success: true, message: 'Posted reminder to social media.' } }
      end
    else
      Rails.logger.warn "post_social_reminder: SocialService.post_occurrence_reminder returned false"
      error_msg = 'Failed to post to social media. Check that credentials are configured.'
      respond_to do |format|
        format.html { redirect_to @occurrence, alert: error_msg }
        format.json { render json: { success: false, message: error_msg } }
      end
    end
  end

  def generate_ai_reminder
    days_ahead = params[:days].to_i
    days_ahead = 7 unless [1, 7].include?(days_ahead)

    unless OllamaService.configured?
      render json: { success: false, message: 'Ollama server not configured.' }
      return
    end

    generated_text = OllamaService.generate_reminder(@occurrence, days_ahead)

    if generated_text.present?
      render json: { success: true, message: generated_text }
    else
      render json: { success: false, message: 'Failed to generate AI reminder. Check server logs.' }
    end
  end

  private

  def set_occurrence
    @occurrence = EventOccurrence.friendly_find(params[:id])
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
