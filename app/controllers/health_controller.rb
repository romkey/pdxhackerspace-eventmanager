# frozen_string_literal: true

# Health check endpoint for container orchestration and monitoring
# Returns status of the application and its dependencies
class HealthController < ApplicationController
  # Skip authentication - authenticate_user! may not be defined as a before_action
  # in ApplicationController (it's defined by Devise in specific controllers)
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :load_site_config

  # GET /health or /up
  # Returns 200 OK if the application is healthy
  # Returns 503 Service Unavailable if any critical dependency is down
  def show
    checks = {
      database: check_database,
      redis: check_redis,
      migrations: check_migrations
    }

    # Consider 'ok', 'skipped', and 'warning' as healthy states; only 'error' is unhealthy
    status = checks.values.none? { |c| c[:status] == 'error' } ? :ok : :service_unavailable

    render json: {
      status: status == :ok ? 'healthy' : 'unhealthy',
      timestamp: Time.current.iso8601,
      version: ENV.fetch('APP_VERSION', 'unknown'),
      checks: checks
    }, status: status
  end

  # GET /health/live
  # Simple liveness probe - just confirms the app is running
  def live
    head :ok
  end

  # GET /health/ready
  # Readiness probe - confirms the app can handle requests
  def ready
    if check_database[:status] == 'ok'
      head :ok
    else
      head :service_unavailable
    end
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', response_time_ms: measure_time { ActiveRecord::Base.connection.execute('SELECT 1') } }
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def check_redis
    redis_url = ENV.fetch('REDIS_URL', nil)
    return { status: 'skipped', message: 'Redis not configured' } unless redis_url

    redis = Redis.new(url: redis_url)
    redis.ping
    { status: 'ok', response_time_ms: measure_time { redis.ping } }
  rescue StandardError => e
    { status: 'error', message: e.message }
  ensure
    redis&.close
  end

  def check_migrations
    migrations_path = Rails.root.join('db/migrate')
    context = ActiveRecord::MigrationContext.new(migrations_path)
    return { status: 'ok' } unless context.needs_migration?

    { status: 'warning', message: 'Pending migrations' }
  rescue StandardError => e
    { status: 'error', message: e.message }
  end

  def measure_time
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  end
end
