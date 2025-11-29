require 'net/http'
require 'uri'
require 'json'

class SocialService
  class << self
    include Rails.application.routes.url_helpers

    def post_instagram(message, image_url: nil) # rubocop:disable Lint/UnusedMethodArgument
      token = ENV.fetch('INSTAGRAM_ACCESS_TOKEN', nil)
      page_id = ENV.fetch('INSTAGRAM_PAGE_ID', nil)

      if token.blank? || page_id.blank?
        Rails.logger.info 'SocialService: Instagram not configured (missing INSTAGRAM_ACCESS_TOKEN or INSTAGRAM_PAGE_ID)'
        return false
      end

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

      if handle.blank? || app_password.blank?
        Rails.logger.info 'SocialService: Bluesky not configured (missing BLUESKY_HANDLE or BLUESKY_APP_PASSWORD)'
        return false
      end

      Rails.logger.info "SocialService: Bluesky post starting for handle #{handle}"

      session = create_bluesky_session(handle, app_password)
      return false unless session

      access_token = session['accessJwt']
      did = session['did']
      Rails.logger.info "SocialService: Bluesky session created for DID #{did}"

      image_blob = fetch_bluesky_image_blob(access_token, image_url)
      record = build_bluesky_record(message, image_blob, image_alt)

      uri = URI('https://bsky.social/xrpc/com.atproto.repo.createRecord')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{access_token}"
      request['Content-Type'] = 'application/json'
      request.body = { repo: did, collection: 'app.bsky.feed.post', record: record }.to_json

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

    def fetch_bluesky_image_blob(access_token, image_url)
      return nil if image_url.blank?

      Rails.logger.info "SocialService: Bluesky image URL provided: #{image_url}"
      blob = upload_bluesky_image(access_token, image_url)
      if blob
        Rails.logger.info "SocialService: Bluesky image blob obtained successfully"
      else
        Rails.logger.warn "SocialService: Bluesky image upload returned nil, posting without image"
      end
      blob
    end

    def build_bluesky_record(message, image_blob, image_alt)
      record = { '$type': 'app.bsky.feed.post', createdAt: Time.current.iso8601, text: message }

      if image_blob
        Rails.logger.info "SocialService: Adding image embed to Bluesky post"
        record[:embed] = {
          '$type': 'app.bsky.embed.images',
          images: [{ alt: image_alt, image: image_blob }]
        }
      end

      record
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

      # Fetch the image from the URL, following redirects
      image_data, content_type = fetch_image_with_redirects(image_url)

      unless image_data
        Rails.logger.error "SocialService: Failed to fetch image from #{image_url}"
        return nil
      end

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

    def fetch_image_with_redirects(url, redirect_limit = 5)
      return nil if redirect_limit.zero?

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        content_type = response['Content-Type'] || 'image/jpeg'
        [response.body, content_type]
      when Net::HTTPRedirection
        new_location = response['Location']
        Rails.logger.info "SocialService: Following redirect to #{new_location}"
        fetch_image_with_redirects(new_location, redirect_limit - 1)
      else
        Rails.logger.error "SocialService: Failed to fetch image (#{response.code}) from #{url}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "SocialService: Error fetching image: #{e.class}: #{e.message}"
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
