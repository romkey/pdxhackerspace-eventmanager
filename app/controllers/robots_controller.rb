# frozen_string_literal: true

class RobotsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    respond_to do |format|
      format.text { render plain: robots_content, content_type: 'text/plain' }
    end
  end

  private

  def robots_content
    if SiteConfig.current.disallow_robots?
      <<~ROBOTS
        # This site is configured to disallow all robots
        User-agent: *
        Disallow: /
      ROBOTS
    else
      <<~ROBOTS
        # Allow all robots
        User-agent: *
        Disallow:

        # Sitemap location
        Sitemap: #{root_url}sitemap.xml
      ROBOTS
    end
  end
end
