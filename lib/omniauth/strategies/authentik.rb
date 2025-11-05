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
          # DEBUG: Log the access token
          Rails.logger.info "=" * 80
          Rails.logger.info "AUTHENTIK ACCESS TOKEN:"
          Rails.logger.info "Token: #{access_token.token}"
          Rails.logger.info "Params keys: #{access_token.params.keys.inspect}"
          Rails.logger.info "Params (full):"
          Rails.logger.info JSON.pretty_generate(access_token.params)
          Rails.logger.info "=" * 80

          # Always fetch and dump userinfo
          Rails.logger.info "FETCHING /userinfo/ endpoint..."
          userinfo_response = access_token.get('/application/o/userinfo/')
          userinfo = userinfo_response.parsed

          Rails.logger.info "=" * 80
          Rails.logger.info "/USERINFO/ RESPONSE:"
          Rails.logger.info JSON.pretty_generate(userinfo)
          Rails.logger.info "=" * 80

          # Also decode the JWT ID token to get additional claims
          if access_token.params['id_token']
            Rails.logger.info "DECODING JWT ID TOKEN..."
            # Decode without verification (already verified by Authentik)
            jwt_payload = JWT.decode(access_token.params['id_token'], nil, false).first

            Rails.logger.info "=" * 80
            Rails.logger.info "JWT ID TOKEN PAYLOAD (decoded):"
            Rails.logger.info JSON.pretty_generate(jwt_payload)
            Rails.logger.info "=" * 80

            # Merge JWT claims into userinfo (JWT claims take precedence)
            merged = userinfo.merge(jwt_payload)

            Rails.logger.info "=" * 80
            Rails.logger.info "MERGED RESULT (userinfo + JWT):"
            Rails.logger.info JSON.pretty_generate(merged)
            Rails.logger.info "=" * 80

            merged
          else
            Rails.logger.warn "NO ID TOKEN FOUND IN ACCESS TOKEN PARAMS!"
            userinfo
          end
        end
      end
    end
  end
end
