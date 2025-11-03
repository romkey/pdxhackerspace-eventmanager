class HomeController < ApplicationController
  def index
    @site_config = SiteConfig.current
    @upcoming_events = policy_scope(Event)
                        .includes(:user, :hosts)
                        .active
                        .where('start_time >= ?', Time.now)
                        .order(:start_time)
                        .limit(5)
  end
end
