require 'omniauth-oauth2'
require 'jwt'

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

      def raw_info
        @raw_info ||= begin
          # Get userinfo from endpoint
          userinfo = access_token.get('/application/o/userinfo/').parsed

          # Also decode the JWT ID token to get additional claims
          if access_token.params['id_token']
            # Decode without verification (already verified by Authentik)
            jwt_payload = JWT.decode(access_token.params['id_token'], nil, false).first
            # Merge JWT claims into userinfo (JWT claims take precedence)
            userinfo.merge(jwt_payload)
          else
            userinfo
          end
        end
      end
    end
  end
end
