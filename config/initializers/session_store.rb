# frozen_string_literal: true

# Configure session storage for production behind reverse proxy
# This ensures cookies work correctly when the app is behind an HTTPS-terminating proxy

Rails.application.config.session_store :cookie_store,
                                       key: '_event_manager_session',
                                       same_site: :lax,
                                       secure: Rails.env.production?
