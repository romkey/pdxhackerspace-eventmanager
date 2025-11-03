module ApplicationHelper
  def authentik_configured?
    ENV['AUTHENTIK_CLIENT_ID'].present? && 
    ENV['AUTHENTIK_CLIENT_SECRET'].present? && 
    ENV['AUTHENTIK_SITE_URL'].present?
  end
end
