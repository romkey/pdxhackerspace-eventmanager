require 'net/http'
require 'uri'
require 'json'

class SocialService
  INSTAGRAM_TOKEN = ENV.fetch('INSTAGRAM_ACCESS_TOKEN', nil)
  INSTAGRAM_PAGE_ID = ENV.fetch('INSTAGRAM_PAGE_ID', nil)

  BLUESKY_TOKEN = ENV.fetch('BLUESKY_ACCESS_TOKEN', nil)
  BLUESKY_HANDLE = ENV.fetch('BLUESKY_HANDLE', nil)

  def self.post_instagram(message)
    return false if INSTAGRAM_TOKEN.blank? || INSTAGRAM_PAGE_ID.blank?

    uri = URI("https://graph.facebook.com/v17.0/#{INSTAGRAM_PAGE_ID}/feed")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{INSTAGRAM_TOKEN}"
    request.set_form_data({ message: message })

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info 'SocialService: Posted reminder to Instagram'
      true
    else
      Rails.logger.error "SocialService: Failed to post to Instagram (#{response.code}) #{response.body}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "SocialService: Instagram error - #{e.message}"
    false
  end

  def self.post_bluesky(message)
    return false if BLUESKY_TOKEN.blank? || BLUESKY_HANDLE.blank?

    uri = URI('https://bsky.social/xrpc/com.atproto.server.createRecord')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{BLUESKY_TOKEN}"
    request['Content-Type'] = 'application/json'
    request.body = {
      repo: BLUESKY_HANDLE,
      collection: 'app.bsky.feed.post',
      record: {
        createdAt: Time.current.iso8601,
        text: message
      }
    }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info 'SocialService: Posted reminder to Bluesky'
      true
    else
      Rails.logger.error "SocialService: Failed to post to Bluesky (#{response.code}) #{response.body}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "SocialService: Bluesky error - #{e.message}"
    false
  end
end
