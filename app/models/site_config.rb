class SiteConfig < ApplicationRecord
  DEFAULT_AI_REMINDER_PROMPT = "Create a short, friendly reminder for {{event_title}} happening on {{event_date}} at {{event_time}} at PDX Hackerspace.".freeze

  has_one_attached :favicon
  has_one_attached :banner_image

  validates :organization_name, presence: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email" },
                            allow_blank: true
  validates :website_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL (starting with http:// or https://)" }, allow_blank: true

  # Singleton pattern - only one site config should exist with id = 1
  def self.instance
    find_by(id: 1) || create_singleton!
  end

  def self.create_singleton!
    # Explicitly create with id = 1 to satisfy the singleton constraint
    config = new(id: 1, organization_name: 'EventManager')
    config.save!
    config
  end

  def self.current
    instance
  end

  def ai_reminder_prompt_with_default
    ai_reminder_prompt.presence || DEFAULT_AI_REMINDER_PROMPT
  end
end
