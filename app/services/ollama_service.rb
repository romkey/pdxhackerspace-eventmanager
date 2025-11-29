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

    def generate(prompt, model: nil)
      return nil unless configured?

      model ||= SiteConfig.current.ai_model.presence || 'llama2'

      Rails.logger.info "OllamaService: Generating with model '#{model}'"
      Rails.logger.debug { "OllamaService: Prompt: #{prompt.truncate(200)}" }

      uri = URI.parse("#{ollama_server}/api/generate")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = 60 # AI generation can take a while

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        model: model,
        prompt: prompt,
        stream: false
      }.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        generated_text = data['response']&.strip
        Rails.logger.info "OllamaService: Generated #{generated_text&.length || 0} characters"
        generated_text
      else
        Rails.logger.error "OllamaService: Generation failed (#{response.code}) #{response.body.truncate(500)}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "OllamaService: Generation error - #{e.class}: #{e.message}"
      nil
    end

    def generate_reminder(occurrence, days_ahead)
      return nil unless configured?

      event = occurrence.event
      date_str = occurrence.occurs_at.strftime('%B %d, %Y')
      time_str = occurrence.occurs_at.strftime('%I:%M %p')

      # Build the prompt from the template
      prompt_template = SiteConfig.current.ai_reminder_prompt_with_default
      base_prompt = prompt_template
                    .gsub(/\{\{\s*event_title\s*\}\}/i, event.title)
                    .gsub(/\{\{\s*event_date\s*\}\}/i, date_str)
                    .gsub(/\{\{\s*event_time\s*\}\}/i, time_str)
                    .gsub(/\{\{\s*event_description\s*\}\}/i, event.description.to_s)

      # Add context about the timing
      timing_context = days_ahead == 7 ? "one week away" : "tomorrow"

      full_prompt = <<~PROMPT
        #{base_prompt}

        This reminder is for an event that is #{timing_context}.
        Keep the message concise (under 280 characters if possible), friendly, and engaging.
        Include the event name, date, time, and mention it's at PDX Hackerspace.
        Do not use hashtags or emojis unless they're already in the event description.
        Just output the reminder text, nothing else.
      PROMPT

      generate(full_prompt)
    end

    private

    def ollama_server
      ENV.fetch('OLLAMA_SERVER', nil)
    end
  end
end
