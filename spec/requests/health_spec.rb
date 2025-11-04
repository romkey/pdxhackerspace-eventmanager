require 'rails_helper'

RSpec.describe "Health", type: :request do
  # Mock Redis and Sidekiq for all tests since they may not be available in CI
  before do
    # Mock successful Redis connection
    redis_double = instance_double(Redis)
    allow(redis_double).to receive_messages(ping: 'PONG', info: { 'connected_clients' => 5 })
    allow(redis_double).to receive(:close)
    allow(Redis).to receive(:new).and_return(redis_double)

    # Mock successful Sidekiq stats
    sidekiq_stats = instance_double(Sidekiq::Stats,
                                    processed: 100,
                                    failed: 2,
                                    scheduled_size: 5,
                                    retry_size: 1,
                                    dead_size: 0,
                                    queues: { 'default' => 3 })
    allow(Sidekiq::Stats).to receive(:new).and_return(sidekiq_stats)
  end

  describe "GET /health/liveness" do
    it "returns success status" do
      get '/health/liveness'
      expect(response).to have_http_status(:success)
    end

    it "returns JSON with ok status" do
      get '/health/liveness'
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
      expect(json['timestamp']).to be_present
    end

    it "does not require authentication" do
      get '/health/liveness'
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /health/readiness" do
    it "returns success when all services are healthy" do
      get '/health/readiness'
      expect(response).to have_http_status(:success)
    end

    it "returns JSON with health check results" do
      get '/health/readiness'
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ready')
      expect(json['checks']).to be_present
      expect(json['checks']['database']['status']).to eq('ok')
      expect(json['checks']['redis']['status']).to eq('ok')
      expect(json['checks']['storage']['status']).to eq('ok')
    end

    it "returns 503 when database is unavailable" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, 'Database error')
      get '/health/readiness'
      expect(response).to have_http_status(:service_unavailable)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('not_ready')
      expect(json['checks']['database']['status']).to eq('error')
    end

    it "returns 503 when Redis is unavailable" do
      allow(Redis).to receive(:new).and_raise(StandardError, 'Redis error')
      get '/health/readiness'
      expect(response).to have_http_status(:service_unavailable)
    end

    it "does not require authentication" do
      get '/health/readiness'
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /health" do
    it "returns success when all services are healthy" do
      get '/health'
      expect(response).to have_http_status(:success)
    end

    it "returns comprehensive health information" do
      get '/health'
      json = JSON.parse(response.body)
      expect(json['status']).to eq('healthy')
      expect(json['checks']).to be_present
      expect(json['checks']['database']).to be_present
      expect(json['checks']['redis']).to be_present
      expect(json['checks']['storage']).to be_present
      expect(json['checks']['sidekiq']).to be_present
      expect(json['app_version']).to be_present
      expect(json['environment']).to eq('test')
      expect(json['timestamp']).to be_present
    end

    it "returns Sidekiq statistics" do
      get '/health'
      json = JSON.parse(response.body)
      sidekiq_check = json['checks']['sidekiq']
      expect(sidekiq_check['status']).to eq('ok')
      expect(sidekiq_check).to have_key('processed')
      expect(sidekiq_check).to have_key('failed')
      expect(sidekiq_check).to have_key('scheduled_size')
    end

    it "returns 503 when any service is unhealthy" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, 'Database error')
      get '/health'
      expect(response).to have_http_status(:service_unavailable)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('unhealthy')
    end

    it "does not require authentication" do
      get '/health'
      expect(response).to have_http_status(:success)
    end

    it "does not expose sensitive information" do
      get '/health'
      json = JSON.parse(response.body)
      body_string = response.body.downcase
      expect(body_string).not_to include('password')
      expect(body_string).not_to include('secret')
      expect(body_string).not_to include('token')
    end
  end

  describe "health check components" do
    let(:controller) { HealthController.new }

    describe "#check_database" do
      it "returns ok when database is accessible" do
        result = controller.send(:check_database)
        expect(result[:status]).to eq('ok')
      end

      it "returns error when database is not accessible" do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, 'Test error')
        result = controller.send(:check_database)
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Test error')
      end
    end

    describe "#check_redis" do
      it "returns ok when Redis is accessible" do
        result = controller.send(:check_redis)
        expect(result[:status]).to eq('ok')
      end
    end

    describe "#check_storage" do
      it "returns ok when storage is accessible" do
        result = controller.send(:check_storage)
        expect(result[:status]).to eq('ok')
      end

      it "returns error when storage is not accessible" do
        allow(ActiveStorage::Blob).to receive(:limit).and_raise(StandardError, 'Test error')
        result = controller.send(:check_storage)
        expect(result[:status]).to eq('error')
      end
    end

    describe "#check_sidekiq" do
      it "returns ok with statistics when Sidekiq is accessible" do
        result = controller.send(:check_sidekiq)
        expect(result[:status]).to eq('ok')
        expect(result[:processed]).to be_a(Integer)
        expect(result[:failed]).to be_a(Integer)
      end

      it "returns error when Sidekiq is not accessible" do
        allow(Sidekiq::Stats).to receive(:new).and_raise(StandardError, 'Test error')
        result = controller.send(:check_sidekiq)
        expect(result[:status]).to eq('error')
      end
    end
  end
end
