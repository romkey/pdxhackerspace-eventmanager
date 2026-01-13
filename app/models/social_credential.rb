# frozen_string_literal: true

class SocialCredential < ApplicationRecord
  PLATFORMS = %w[instagram facebook bluesky].freeze
  REFRESH_THRESHOLD = 7.days # Refresh when less than 7 days until expiration

  validates :platform, presence: true, uniqueness: true, inclusion: { in: PLATFORMS }
  validates :access_token, presence: true

  encrypts :access_token
  encrypts :refresh_token

  scope :for_platform, ->(platform) { find_by(platform: platform) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def needs_refresh?
    return false if expires_at.blank?

    expires_at <= REFRESH_THRESHOLD.from_now
  end

  def self.get_token(platform)
    credential = for_platform(platform)
    return nil unless credential

    # Check if refresh is needed
    credential.refresh! if credential.needs_refresh? && credential.can_refresh?

    credential.expired? ? nil : credential.access_token
  end

  def can_refresh?
    # Instagram/Facebook tokens can be refreshed if we have app credentials
    return false unless platform == 'instagram'

    ENV['INSTAGRAM_APP_ID'].present? && ENV['INSTAGRAM_APP_SECRET'].present?
  end

  def refresh!
    return false unless can_refresh?

    case platform
    when 'instagram'
      refresh_instagram_token!
    else
      false
    end
  end

  private

  def refresh_instagram_token!
    app_id = ENV.fetch('INSTAGRAM_APP_ID', nil)
    app_secret = ENV.fetch('INSTAGRAM_APP_SECRET', nil)

    uri = URI('https://graph.facebook.com/v21.0/oauth/access_token')
    uri.query = URI.encode_www_form(
      grant_type: 'fb_exchange_token',
      client_id: app_id,
      client_secret: app_secret,
      fb_exchange_token: access_token
    )

    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      update!(
        access_token: data['access_token'],
        expires_at: data['expires_in'] ? data['expires_in'].seconds.from_now : 60.days.from_now
      )
      Rails.logger.info "SocialCredential: Refreshed Instagram token, expires at #{expires_at}"
      true
    else
      Rails.logger.error "SocialCredential: Failed to refresh Instagram token: #{response.body}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "SocialCredential: Error refreshing Instagram token: #{e.message}"
    false
  end
end
