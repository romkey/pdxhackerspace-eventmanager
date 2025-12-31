require 'sidekiq/testing'

RSpec.configure do |config|
  config.before(:each) do
    # Use fake mode by default - jobs are pushed to a fake queue
    Sidekiq::Testing.fake!
  end

  config.after(:each) do
    # Clear any queued jobs after each test
    Sidekiq::Worker.clear_all
  end
end

