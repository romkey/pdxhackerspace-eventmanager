class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :load_site_config

  # Basic liveness check - is the app responding?
  def liveness
    render json: {
      status: 'ok',
      timestamp: Time.now.iso8601
    }, status: :ok
  end

  # Readiness check - is the app ready to serve traffic?
  def readiness
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage
    }

    all_healthy = checks.values.all? { |check| check[:status] == 'ok' }
    status_code = all_healthy ? :ok : :service_unavailable

    render json: {
      status: all_healthy ? 'ready' : 'not_ready',
      checks: checks,
      timestamp: Time.now.iso8601
    }, status: status_code
  end

  # Detailed health check with component status
  def health
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage,
      sidekiq: check_sidekiq
    }

    all_healthy = checks.values.all? { |check| check[:status] == 'ok' }

    render json: {
      status: all_healthy ? 'healthy' : 'unhealthy',
      checks: checks,
      app_version: app_version,
      environment: Rails.env,
      timestamp: Time.now.iso8601
    }, status: all_healthy ? :ok : :service_unavailable
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', message: 'Database connection successful' }
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def check_redis
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0'))
    redis.ping
    { status: 'ok', message: 'Redis connection successful' }
  rescue StandardError => e
    { status: 'error', message: e.message }
  ensure
    redis&.close
  end

  def check_storage
    # Check if Active Storage is configured and accessible
    ActiveStorage::Blob.limit(1).pluck(:id)
    { status: 'ok', message: 'Storage accessible' }
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def check_sidekiq
    # Check if Sidekiq can connect to Redis
    stats = Sidekiq::Stats.new
    {
      status: 'ok',
      message: 'Sidekiq operational',
      processed: stats.processed,
      failed: stats.failed,
      scheduled_size: stats.scheduled_size,
      retry_size: stats.retry_size,
      dead_size: stats.dead_size
    }
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def app_version
    # Try to read version from a VERSION file or git
    version_file = Rails.root.join('VERSION')
    return File.read(version_file).strip if File.exist?(version_file)

    # Try git describe
    `git describe --tags --always 2>/dev/null`.strip.presence || 'unknown'
  rescue StandardError
    'unknown'
  end
end
