require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Authentik < OmniAuth::Strategies::OAuth2
      option :name, 'authentik'

      option :client_options, {
        site: ENV['AUTHENTIK_SITE_URL'],
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
        @raw_info ||= access_token.get('/application/o/userinfo/').parsed
      end
    end
  end
end

