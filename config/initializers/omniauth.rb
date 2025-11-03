# Explicitly require the Authentik strategy before using it
# Rails 7.1 autoloader expects directory names to match module names (case-sensitive)
# Since we have lib/omniauth (lowercase) but OmniAuth module (capital A), we require explicitly
require_relative '../../lib/omniauth/strategies/authentik'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :authentik,
           ENV.fetch('AUTHENTIK_CLIENT_ID', nil),
           ENV.fetch('AUTHENTIK_CLIENT_SECRET', nil),
           client_options: {
             site: ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000',
             authorize_url: "#{ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000'}/application/o/authorize/",
             token_url: "#{ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000'}/application/o/token/",
             user_info_url: "#{ENV['AUTHENTIK_SITE_URL'] || 'http://localhost:9000'}/application/o/userinfo/"
           }
end

# Configure OmniAuth to use Rails CSRF protection
OmniAuth.config.allowed_request_methods = %i[post get]
