module ApplicationHelper
  def authentik_configured?
    ENV['AUTHENTIK_CLIENT_ID'].present? &&
      ENV['AUTHENTIK_CLIENT_SECRET'].present? &&
      ENV['AUTHENTIK_SITE_URL'].present?
  end

  def can_create_events?
    user_signed_in? && (current_user.admin? || current_user.can_create_events?)
  end
end
