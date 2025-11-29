# frozen_string_literal: true

# Rack::Attack configuration for rate limiting
# https://github.com/rack/rack-attack

module Rack
  class Attack
    ### Configure Cache ###
    # Use Rails cache for storing rate limit data
    # In production with Redis, this provides distributed rate limiting
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    ### Safelist ###
    # Always allow requests from localhost (for development and health checks)
    safelist('allow-localhost') do |req|
      ['127.0.0.1', '::1'].include?(req.ip)
    end

    ### Throttle Authentication Endpoints ###

    # Limit sign-in attempts by IP address
    # 5 requests per 20 seconds
    throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
      req.ip if req.path == '/users/sign_in' && req.post?
    end

    # Limit sign-in attempts by email parameter
    # 5 requests per 20 seconds per email
    throttle('logins/email', limit: 5, period: 20.seconds) do |req|
      if req.path == '/users/sign_in' && req.post?
        # Normalize email to prevent case-based bypasses
        req.params.dig('user', 'email')&.downcase&.strip
      end
    end

    # Limit OAuth callback attempts
    # 10 requests per minute
    throttle('oauth/ip', limit: 10, period: 1.minute) do |req|
      req.ip if req.path.start_with?('/users/auth/')
    end

    # Limit password reset requests
    # 5 requests per hour per IP
    throttle('password_reset/ip', limit: 5, period: 1.hour) do |req|
      req.ip if req.path == '/users/password' && req.post?
    end

    # Limit password reset by email
    # 3 requests per hour per email
    throttle('password_reset/email', limit: 3, period: 1.hour) do |req|
      req.params.dig('user', 'email')&.downcase&.strip if req.path == '/users/password' && req.post?
    end

    ### General API Rate Limiting ###

    # Limit all requests by IP (general protection)
    # 300 requests per 5 minutes
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets', '/packs')
    end

    ### Blocklist ###

    # Block requests with suspicious patterns (basic protection)
    blocklist('block-bad-actors') do |req|
      # Block requests trying to access common attack vectors
      Rack::Attack::Fail2Ban.filter("pentest-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
        # Detect scanning for vulnerabilities
        CGI.unescape(req.query_string).include?('etc/passwd') ||
          req.path.include?('wp-admin') ||
          req.path.include?('wp-login') ||
          req.path.include?('.php') ||
          req.path.include?('phpmyadmin')
      end
    end

    ### Custom Responses ###

    # Return 429 Too Many Requests with retry information
    self.throttled_responder = lambda do |request|
      match_data = request.env['rack.attack.match_data']
      now = match_data[:epoch_time]
      retry_after = match_data[:period] - (now % match_data[:period])

      headers = {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      }

      body = {
        error: 'Rate limit exceeded',
        retry_after: retry_after
      }.to_json

      [429, headers, [body]]
    end

    # Return 403 Forbidden for blocked requests
    self.blocklisted_responder = lambda do |_request|
      [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']]
    end
  end
end

# Log throttled and blocked requests in development/production
ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[Rack::Attack] Throttled #{req.ip} for #{req.path}")
end

ActiveSupport::Notifications.subscribe('blocklist.rack_attack') do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[Rack::Attack] Blocked #{req.ip} for #{req.path}")
end
