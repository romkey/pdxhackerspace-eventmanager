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
      handle = ENV.fetch('BLUESKY_HANDLE', nil)
      app_password = ENV.fetch('BLUESKY_APP_PASSWORD', nil)
      return false if handle.blank? || app_password.blank?

      Rails.logger.info "SocialService: Bluesky post starting for handle #{handle}"

      # First, create a session to get an access token
      session = create_bluesky_session(handle, app_password)
      return false unless session

      access_token = session['accessJwt']
      did = session['did']
      Rails.logger.info "SocialService: Bluesky session created for DID #{did}"

      # If we have an image URL, upload it first
      image_blob = nil
      if image_url.present?
        Rails.logger.info "SocialService: Bluesky image URL provided: #{image_url}"
        image_blob = upload_bluesky_image(access_token, image_url)
        if image_blob
          Rails.logger.info "SocialService: Bluesky image blob obtained successfully"
        else
          Rails.logger.warn "SocialService: Bluesky image upload returned nil, posting without image"
        end
      else
        Rails.logger.info "SocialService: No image URL provided for Bluesky post"
      end

      record = {
        '$type': 'app.bsky.feed.post',
        createdAt: Time.current.iso8601,
        text: message
      }

      # Add image embed if we successfully uploaded
      if image_blob
        Rails.logger.info "SocialService: Adding image embed to Bluesky post"
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
      request['Authorization'] = "Bearer #{access_token}"
      request['Content-Type'] = 'application/json'
      request.body = {
        repo: did,
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

      Rails.logger.info "SocialService: Posting occurrence reminder for '#{occurrence.event.title}'"
      Rails.logger.info "SocialService: Banner image URL: #{image_url || 'none'}"

      success_instagram = post_instagram(message, image_url: image_url)
      success_bluesky = post_bluesky(message, image_url: image_url, image_alt: image_alt)

      success_instagram || success_bluesky
    end

    private

    def create_bluesky_session(handle, app_password)
      uri = URI('https://bsky.social/xrpc/com.atproto.server.createSession')
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        identifier: handle,
        password: app_password
      }.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        Rails.logger.error "SocialService: Failed to create Bluesky session (#{response.code}) #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "SocialService: Bluesky session error - #{e.message}"
      nil
    end

    def upload_bluesky_image(token, image_url)
      Rails.logger.info "SocialService: Fetching image from #{image_url}"

      # Fetch the image from the URL
      image_uri = URI.parse(image_url)
      image_response = Net::HTTP.get_response(image_uri)

      unless image_response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "SocialService: Failed to fetch image (#{image_response.code}) from #{image_url}"
        Rails.logger.error "SocialService: Image fetch response: #{image_response.body.to_s.truncate(500)}"
        return nil
      end

      image_data = image_response.body
      content_type = image_response['Content-Type'] || 'image/jpeg'
      Rails.logger.info "SocialService: Fetched image - size: #{image_data.bytesize} bytes, content-type: #{content_type}"

      # Upload to Bluesky
      uri = URI('https://bsky.social/xrpc/com.atproto.repo.uploadBlob')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Content-Type'] = content_type
      request.body = image_data

      Rails.logger.info "SocialService: Uploading image to Bluesky..."
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        Rails.logger.info "SocialService: Uploaded image to Bluesky successfully"
        Rails.logger.debug { "SocialService: Bluesky blob response: #{data.inspect}" }
        data['blob']
      else
        Rails.logger.error "SocialService: Failed to upload image to Bluesky (#{response.code}) #{response.body}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "SocialService: Bluesky image upload error - #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    def banner_url_for(occurrence)
      host = ENV.fetch('RAILS_HOST', ENV.fetch('HOST', 'localhost:3000'))
      protocol = ENV.fetch('RAILS_PROTOCOL', 'http')

      if occurrence.banner_image.attached?
        url = rails_blob_url(occurrence.banner_image, host: host, protocol: protocol)
        Rails.logger.info "SocialService: Using occurrence banner image: #{url}"
        url
      elsif occurrence.event.banner_image.attached?
        url = rails_blob_url(occurrence.event.banner_image, host: host, protocol: protocol)
        Rails.logger.info "SocialService: Using event banner image: #{url}"
        url
      else
        Rails.logger.info "SocialService: No banner image attached to occurrence or event"
        nil
      end
    end
  end
end
