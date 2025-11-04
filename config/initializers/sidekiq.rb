require 'sidekiq'
require 'sidekiq-scheduler'

# Sidekiq configuration
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0') }

  # Load the schedule from sidekiq.yml
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq.yml', __dir__))[:schedule]
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0') }
end

# Configure Rails to use Sidekiq as the Active Job queue adapter
Rails.application.config.active_job.queue_adapter = :sidekiq
