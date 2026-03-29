# Authentik strategy is loaded in 00_load_omniauth_strategies.rb

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :authentik,
           ENV.fetch('AUTHENTIK_CLIENT_ID', nil),
           ENV.fetch('AUTHENTIK_CLIENT_SECRET', nil),
           scope: 'openid profile email member-roles',
           client_options: {
             site: ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000',
             authorize_url: "#{ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000'}/application/o/authorize/",
             token_url: "#{ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000'}/application/o/token/",
             user_info_url: "#{ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000'}/application/o/userinfo/"
           }
end

# CSRF Protection for OmniAuth
# Only allow POST requests to prevent CSRF attacks (CVE-2015-9284)
# The omniauth-rails_csrf_protection gem (2.0+) handles CSRF token verification
OmniAuth.config.allowed_request_methods = [:post]
