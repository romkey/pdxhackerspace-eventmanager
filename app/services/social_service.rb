require 'net/http'
require 'uri'
require 'json'

class SocialService
  class << self
    include Rails.application.routes.url_helpers

    def post_instagram(message, image_url: nil) # rubocop:disable Lint/UnusedMethodArgument
      token = ENV.fetch('INSTAGRAM_ACCESS_TOKEN', nil)
      page_id = ENV.fetch('INSTAGRAM_PAGE_ID', nil)
      return false if token.blank? || page_id.blank?

      uri = URI("https://graph.facebook.com/v17.0/#{page_id}/feed")
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{token}"
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

    def post_bluesky(message, image_url: nil, image_alt: 'Event banner')
      token = ENV.fetch('BLUESKY_ACCESS_TOKEN', nil)
      handle = ENV.fetch('BLUESKY_HANDLE', nil)
      return false if token.blank? || handle.blank?

      # If we have an image URL, upload it first
      image_blob = upload_bluesky_image(token, image_url) if image_url.present?

      record = {
        '$type': 'app.bsky.feed.post',
        createdAt: Time.current.iso8601,
        text: message
      }

      # Add image embed if we successfully uploaded
      if image_blob
        record[:embed] = {
          '$type': 'app.bsky.embed.images',
          images: [
            {
              alt: image_alt,
              image: image_blob
            }
          ]
        }
      end

      uri = URI('https://bsky.social/xrpc/com.atproto.repo.createRecord')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = 'application/json'
      request.body = {
        repo: handle,
        collection: 'app.bsky.feed.post',
        record: record
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

    def post_occurrence_reminder(occurrence, message)
      image_url = banner_url_for(occurrence)
      image_alt = occurrence.event.title

      success_instagram = post_instagram(message, image_url: image_url)
      success_bluesky = post_bluesky(message, image_url: image_url, image_alt: image_alt)

      success_instagram || success_bluesky
    end

    private

    def upload_bluesky_image(token, image_url)
      # Fetch the image from the URL
      image_uri = URI.parse(image_url)
      image_response = Net::HTTP.get_response(image_uri)

      return nil unless image_response.is_a?(Net::HTTPSuccess)

      image_data = image_response.body
      content_type = image_response['Content-Type'] || 'image/jpeg'

      # Upload to Bluesky
      uri = URI('https://bsky.social/xrpc/com.atproto.repo.uploadBlob')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = content_type
      request.body = image_data

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        Rails.logger.info 'SocialService: Uploaded image to Bluesky'
        data['blob']
      else
        Rails.logger.error "SocialService: Failed to upload image to Bluesky (#{response.code}) #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "SocialService: Bluesky image upload error - #{e.message}"
      nil
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
