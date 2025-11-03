class SiteConfig < ApplicationRecord
  has_one_attached :favicon
  has_one_attached :banner_image

  validates :organization_name, presence: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email" }, allow_blank: true
  validates :website_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL (starting with http:// or https://)" }, allow_blank: true

  # Singleton pattern - only one site config should exist
  def self.instance
    first_or_create!(organization_name: 'EventManager')
  end

  def self.current
    instance
  end
end
