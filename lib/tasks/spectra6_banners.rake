# frozen_string_literal: true

namespace :banners do
  desc 'Generate spectra6 versions of all existing banner images'
  task generate_spectra6: :environment do
    puts 'Generating spectra6 versions of all banner images...'

    events_with_banners = Event.joins(banner_image_attachment: :blob)
    total = events_with_banners.count

    puts "Found #{total} events with banner images"

    events_with_banners.find_each.with_index do |event, index|
      puts "[#{index + 1}/#{total}] Processing: #{event.title} (ID: #{event.id})"

      blob_id = event.banner_image.blob.id
      Spectra6BannerJob.perform_later(blob_id)

      puts "  ✓ Queued job for blob #{blob_id}"
    end

    puts "\nDone! Queued #{total} jobs for processing."
    puts 'Jobs will be processed by Sidekiq.'
  end

  desc 'Generate spectra6 versions synchronously (for debugging)'
  task generate_spectra6_sync: :environment do
    puts 'Generating spectra6 versions of all banner images (synchronous)...'

    events_with_banners = Event.joins(banner_image_attachment: :blob)
    total = events_with_banners.count
    success = 0
    failed = 0

    puts "Found #{total} events with banner images"

    events_with_banners.find_each.with_index do |event, index|
      puts "[#{index + 1}/#{total}] Processing: #{event.title} (ID: #{event.id})"

      blob_id = event.banner_image.blob.id

      begin
        Spectra6BannerJob.perform_now(blob_id)
        puts '  ✓ Processed successfully'
        success += 1
      rescue StandardError => e
        puts "  ✗ Failed: #{e.message}"
        failed += 1
      end
    end

    puts "\nDone! Processed #{success} successfully, #{failed} failed."
  end
end
