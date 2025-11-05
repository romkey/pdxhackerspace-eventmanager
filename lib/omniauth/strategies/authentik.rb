require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Authentik < OmniAuth::Strategies::OAuth2
      option :name, 'authentik'

      option :client_options, {
        site: ENV.fetch('AUTHENTIK_SITE_URL', nil),
        authorize_url: '/application/o/authorize/',
        token_url: '/application/o/token/'
      }

      uid { raw_info['sub'] }

      info do
        {
          email: raw_info['email'],
          name: raw_info['name'],
          nickname: raw_info['preferred_username']
        }
      end

      extra do
        {
          raw_info: raw_info
        }
      end

      def raw_info
        @raw_info ||= begin
          # Fetch userinfo - this is the source of truth
          Rails.logger.info "FETCHING /userinfo/ endpoint..."
          userinfo_response = access_token.get('/application/o/userinfo/')
          userinfo = userinfo_response.parsed

          # DEBUG: Log what userinfo contains
          Rails.logger.info "=" * 80
          Rails.logger.info "/USERINFO/ RESPONSE (source of truth):"
          Rails.logger.info JSON.pretty_generate(userinfo)
          Rails.logger.info "=" * 80

          userinfo
        end
      end
    end
  end
end
