# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Health", type: :request do
  # Mock Redis for tests since it may not be available in CI
  before do
    # Set up REDIS_URL so check_redis doesn't skip
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('REDIS_URL', nil).and_return('redis://localhost:6379/0')
    allow(ENV).to receive(:fetch).with('APP_VERSION', 'unknown').and_return('test-version')

    # Mock successful Redis connection
    redis_double = instance_double(Redis)
    allow(redis_double).to receive(:ping).and_return('PONG')
    allow(redis_double).to receive(:close)
    allow(Redis).to receive(:new).and_return(redis_double)
  end

  describe "GET /health/liveness" do
    it "returns success status" do
      get '/health/liveness'
      expect(response).to have_http_status(:success)
    end

    it "returns empty body (head :ok)" do
      get '/health/liveness'
      expect(response.body).to be_empty
    end

    it "does not require authentication" do
      get '/health/liveness'
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /health/readiness" do
    it "returns success when database is healthy" do
      get '/health/readiness'
      expect(response).to have_http_status(:success)
    end

    it "returns empty body (head :ok)" do
      get '/health/readiness'
      expect(response.body).to be_empty
    end

    it "returns 503 when database is unavailable" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, 'Database error')
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
      expect(json['checks']['migrations']).to be_present
      expect(json['version']).to be_present
      expect(json['timestamp']).to be_present
    end

    it "returns database check with response time" do
      get '/health'
      json = JSON.parse(response.body)
      db_check = json['checks']['database']
      expect(db_check['status']).to eq('ok')
      expect(db_check['response_time_ms']).to be_a(Numeric)
    end

    it "returns redis check with response time" do
      get '/health'
      json = JSON.parse(response.body)
      redis_check = json['checks']['redis']
      expect(redis_check['status']).to eq('ok')
      expect(redis_check['response_time_ms']).to be_a(Numeric)
    end

    it "returns 503 when database is unhealthy" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, 'Database error')
      get '/health'
      expect(response).to have_http_status(:service_unavailable)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('unhealthy')
      expect(json['checks']['database']['status']).to eq('error')
    end

    it "does not require authentication" do
      get '/health'
      expect(response).to have_http_status(:success)
    end

    it "does not expose sensitive information" do
      get '/health'
      body_string = response.body.downcase
      expect(body_string).not_to include('password')
      expect(body_string).not_to include('secret')
      expect(body_string).not_to include('token')
    end
  end

  describe "health check components" do
    let(:controller) { HealthController.new }

    before do
      # Controller needs request context for some methods
      allow(controller).to receive(:request).and_return(ActionDispatch::TestRequest.create)
    end

    describe "#check_database" do
      it "returns ok when database is accessible" do
        result = controller.send(:check_database)
        expect(result[:status]).to eq('ok')
        expect(result[:response_time_ms]).to be_a(Numeric)
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
        expect(result[:response_time_ms]).to be_a(Numeric)
      end

      it "returns skipped when Redis is not configured" do
        allow(ENV).to receive(:fetch).with('REDIS_URL', nil).and_return(nil)
        result = controller.send(:check_redis)
        expect(result[:status]).to eq('skipped')
      end

      it "returns error when Redis connection fails" do
        allow(Redis).to receive(:new).and_raise(StandardError, 'Connection refused')
        result = controller.send(:check_redis)
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Connection refused')
      end
    end

    describe "#check_migrations" do
      it "returns ok or warning (not error) for migrations" do
        result = controller.send(:check_migrations)
        expect(result[:status]).to be_in(%w[ok warning])
      end
    end
  end
end
