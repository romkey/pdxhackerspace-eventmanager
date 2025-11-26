# frozen_string_literal: true

require 'net/http'
require 'json'

class OllamaService
  class << self
    def available_models
      return [] if ollama_server.blank?

      uri = URI.parse("#{ollama_server}/api/tags")
      response = Net::HTTP.get_response(uri)

      return [] unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      models = data['models'] || []
      models.pluck('name').sort
    rescue StandardError => e
      Rails.logger.warn "OllamaService: Failed to fetch models: #{e.message}"
      []
    end

    def configured?
      ollama_server.present?
    end

    private

    def ollama_server
      ENV.fetch('OLLAMA_SERVER', nil)
    end
  end
end
