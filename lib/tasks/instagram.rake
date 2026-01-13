# frozen_string_literal: true

namespace :instagram do
  desc 'Set up Instagram credential from environment variable'
  task setup: :environment do
    InstagramTaskHelper.setup_credential
  end

  desc 'Check Instagram token status'
  task status: :environment do
    InstagramTaskHelper.show_status
  end

  desc 'Force refresh Instagram token'
  task refresh: :environment do
    InstagramTaskHelper.force_refresh
  end
end

# Helper module to keep rake tasks concise
module InstagramTaskHelper
  class << self
    def setup_credential
      token = ENV.fetch('INSTAGRAM_ACCESS_TOKEN', nil)

      if token.blank?
        puts 'Error: INSTAGRAM_ACCESS_TOKEN environment variable not set'
        exit 1
      end

      credential = SocialCredential.find_or_initialize_by(platform: 'instagram')
      credential.update!(
        access_token: token,
        expires_at: 60.days.from_now,
        metadata: { setup_at: Time.current.iso8601 }
      )

      puts "Instagram credential saved. Expires at: #{credential.expires_at}"
      puts 'Token will auto-refresh if INSTAGRAM_APP_ID and INSTAGRAM_APP_SECRET are set.'
    end

    def show_status
      credential = SocialCredential.for_platform('instagram')

      if credential.nil?
        puts 'No Instagram credential found in database.'
        puts 'Run `rails instagram:setup` to import from INSTAGRAM_ACCESS_TOKEN env var.'
        return
      end

      puts 'Instagram Token Status:'
      puts "  Expires at: #{credential.expires_at || 'Unknown'}"
      puts "  Expired: #{credential.expired? ? 'YES' : 'No'}"
      puts "  Needs refresh: #{credential.needs_refresh? ? 'YES' : 'No'}"
      puts "  Can auto-refresh: #{credential.can_refresh? ? 'Yes' : 'No (set INSTAGRAM_APP_ID and INSTAGRAM_APP_SECRET)'}"
      puts "  Last updated: #{credential.updated_at}"
    end

    def force_refresh
      credential = SocialCredential.for_platform('instagram')

      if credential.nil?
        puts 'No Instagram credential found. Run `rails instagram:setup` first.'
        exit 1
      end

      unless credential.can_refresh?
        puts 'Cannot refresh: INSTAGRAM_APP_ID and INSTAGRAM_APP_SECRET must be set.'
        exit 1
      end

      if credential.refresh!
        puts "Token refreshed successfully. New expiration: #{credential.expires_at}"
      else
        puts 'Token refresh failed. Check logs for details.'
        exit 1
      end
    end
  end
end
