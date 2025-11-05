class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:authentik]

  has_many :events, dependent: :destroy # Events created by this user
  has_many :event_hosts, dependent: :destroy
  has_many :hosted_events, through: :event_hosts, source: :event # Events this user co-hosts

  validates :role, inclusion: { in: %w[user admin] }
  validates :email, presence: true, uniqueness: true

  def admin?
    role == 'admin'
  end

  def self.from_omniauth(auth)
    # DEBUG: Log what Authentik sends to check for event_manager_admin claim
    Rails.logger.info "=" * 80
    Rails.logger.info "AUTHENTIK AUTH DATA:"
    Rails.logger.info "Provider: #{auth.provider}"
    Rails.logger.info "UID: #{auth.uid}"
    Rails.logger.info "Email: #{auth.info.email}"
    Rails.logger.info "Name: #{auth.info.name}"
    Rails.logger.info "Info keys: #{auth.info.to_hash.keys.inspect}"
    Rails.logger.info "Extra keys: #{auth.extra&.to_hash&.keys.inspect}"
    Rails.logger.info "Raw info: #{auth.extra.raw_info.to_hash.inspect}" if auth.extra&.raw_info
    Rails.logger.info "Looking for 'event_manager_admin' claim in raw_info"
    Rails.logger.info "event_manager_admin value: #{auth.extra&.raw_info&.event_manager_admin.inspect}"
    Rails.logger.info "=" * 80

    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = Devise.friendly_token[0, 20]
    end
  end
end
