# frozen_string_literal: true

class RefreshSocialCredentialsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'RefreshSocialCredentialsJob: Checking social credentials for refresh'

    SocialCredential.find_each do |credential|
      next unless credential.needs_refresh?

      Rails.logger.info "RefreshSocialCredentialsJob: #{credential.platform} token needs refresh"

      if credential.can_refresh?
        if credential.refresh!
          Rails.logger.info "RefreshSocialCredentialsJob: #{credential.platform} token refreshed, expires #{credential.expires_at}"
        else
          Rails.logger.error "RefreshSocialCredentialsJob: #{credential.platform} token refresh failed"
        end
      else
        Rails.logger.warn "RefreshSocialCredentialsJob: #{credential.platform} token expiring but cannot auto-refresh"
      end
    end
  end
end
