require 'net/http'
require 'uri'
require 'json'

class SlackService
  def self.post_message(text, channel: '#announcements')
    webhook_url = ENV['SLACK_WEBHOOK_URL']
    return false unless webhook_url.present?

    payload = {
      text: text,
      channel: channel
    }

    uri = URI.parse(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)

    if response.code == '200'
      Rails.logger.info "SlackService: Successfully posted message to #{channel}"
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
end

