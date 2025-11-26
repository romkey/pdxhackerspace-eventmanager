require 'net/http'
require 'uri'
require 'json'

class SlackService
  class << self
    include Rails.application.routes.url_helpers

    def post_message(text, image_url: nil, image_alt: 'Event banner')
      webhook_url = ENV.fetch('SLACK_WEBHOOK_URL', nil)
      return false if webhook_url.blank?

      payload = build_payload(text, image_url, image_alt)

      uri = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json

      response = http.request(request)

      if response.code == '200'
        Rails.logger.info 'SlackService: Successfully posted message'
        true
      else
        Rails.logger.error "SlackService: Failed to post message. Response: #{response.code} #{response.body}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "SlackService: Error posting message: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end

    def post_occurrence_reminder(occurrence, message)
      image_url = banner_url_for(occurrence)
      post_message(message, image_url: image_url, image_alt: occurrence.event.title)
    end

    private

    def build_payload(text, image_url, image_alt)
      if image_url.present?
        {
          blocks: [
            {
              type: 'section',
              text: { type: 'mrkdwn', text: text },
              accessory: {
                type: 'image',
                image_url: image_url,
                alt_text: image_alt
              }
            }
          ],
          text: text # Fallback for notifications
        }
      else
        { text: text }
      end
    end

    def banner_url_for(occurrence)
      host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
      protocol = ENV.fetch('RAILS_PROTOCOL', 'http')

      if occurrence.banner_image.attached?
        rails_blob_url(occurrence.banner_image, host: host, protocol: protocol)
      elsif occurrence.event.banner_image.attached?
        rails_blob_url(occurrence.event.banner_image, host: host, protocol: protocol)
      end
    end
  end
end
