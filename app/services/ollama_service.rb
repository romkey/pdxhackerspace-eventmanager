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

    # Generate a short reminder (for Bluesky)
    # The generated text should use {{when}} as a placeholder for the date/time
    def generate_short_reminder(occurrence, days_ahead)
      return nil unless configured?

      site_config = SiteConfig.current
      max_length = site_config.short_reminder_max_length

      event = occurrence.event
      prompt_template = site_config.ai_reminder_prompt_with_default
      base_prompt = build_base_prompt(prompt_template, event, occurrence)
      timing_context = days_ahead == 7 ? 'one week away' : 'tomorrow'

      full_prompt = <<~PROMPT
        #{base_prompt}

        This reminder is for an event that is #{timing_context}.
        IMPORTANT: The message must be under #{max_length - 20} characters (we need room for a link).
        IMPORTANT: Use {{when}} as a placeholder for the date and time. Do NOT include the actual date/time.
        Example: "Join us for Workshop {{when}} at PDX Hackerspace!"
        Keep the message concise, friendly, and engaging.
        Include the event name, mention it's at PDX Hackerspace, and use {{when}} for timing.
        Do not use hashtags or emojis unless they're already in the event description.
        Just output the reminder text, nothing else.
      PROMPT

      generate(full_prompt)
    end

    # Generate a long reminder (for Slack/Instagram)
    # The generated text should use {{when}} as a placeholder for the date/time
    def generate_long_reminder(occurrence, days_ahead)
      return nil unless configured?

      site_config = SiteConfig.current
      max_length = site_config.long_reminder_max_length

      event = occurrence.event
      prompt_template = site_config.ai_reminder_prompt_with_default
      base_prompt = build_base_prompt(prompt_template, event, occurrence)
      timing_context = days_ahead == 7 ? 'one week away' : 'tomorrow'

      full_prompt = <<~PROMPT
        #{base_prompt}

        This reminder is for an event that is #{timing_context}.
        You can use up to #{max_length} characters for this message.
        IMPORTANT: Use {{when}} as a placeholder for the date and time. Do NOT include the actual date/time.
        Example: "Join us {{when}} at PDX Hackerspace for an exciting workshop!"
        Include the event name, location, and mention it's at PDX Hackerspace.
        Include relevant details from the event description.
        Be friendly and engaging, encouraging people to attend.
        You may use line breaks for readability.
        Do not use hashtags or emojis unless they're already in the event description.
        Just output the reminder text, nothing else.
      PROMPT

      generate(full_prompt)
    end

    # Legacy method - generates short reminder for backwards compatibility
    def generate_reminder(occurrence, days_ahead)
      generate_short_reminder(occurrence, days_ahead)
    end

    private

    def build_base_prompt(prompt_template, event, occurrence)
      prompt_template
        .gsub(/\{\{\s*event_title\s*\}\}/i, event.title)
        .gsub(/\{\{\s*event_description\s*\}\}/i, occurrence.description.to_s)
    end

    def ollama_server
      ENV.fetch('OLLAMA_SERVER', nil)
    end
  end
end
