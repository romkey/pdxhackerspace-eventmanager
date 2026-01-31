# frozen_string_literal: true

class EventJournalsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  PER_PAGE = 100

  def index
    @page = [params[:page].to_i, 1].max
    @journals = EventJournal.includes(:event, :user, :occurrence)
                            .recent_first
                            .offset((@page - 1) * PER_PAGE)
                            .limit(PER_PAGE + 1) # Fetch one extra to check if there's a next page

    @has_next_page = @journals.size > PER_PAGE
    @journals = @journals.first(PER_PAGE) # Trim to actual page size
    @has_prev_page = @page > 1
  end

  private

  def require_admin
    return if current_user&.admin?

    redirect_to root_path, alert: 'You are not authorized to view this page.'
  end
end
