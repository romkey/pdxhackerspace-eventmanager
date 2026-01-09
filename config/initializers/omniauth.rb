# Authentik strategy is loaded in 00_load_omniauth_strategies.rb
# Provider configuration is now in config/initializers/devise.rb
# to ensure proper CSRF protection with omniauth-rails_csrf_protection 2.0+

# Configure OmniAuth to use Rails CSRF protection
# Only allow POST to prevent CSRF attacks (CVE-2015-9284)
OmniAuth.config.allowed_request_methods = [:post]
