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
    # Find or create user
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize

    # Update user info on each login
    user.email = auth.info.email
    user.name = auth.info.name

    # Set role based on Authentik claim
    user.role = determine_role_from_auth(auth)

    # Set password for new users
    user.password = Devise.friendly_token[0, 20] if user.new_record?

    user.save!

    Rails.logger.info "User #{user.email} logged in with role: #{user.role}"

    user
  end

  def self.determine_role_from_auth(auth)
    # Check if Authentik sends the event_manager_admin claim in raw_info
    is_admin_claim = auth.extra&.raw_info&.[]('event_manager_admin')

    # Handle both boolean true and string "true" from Authentik
    # Only set admin if explicitly true (boolean) or "true" (string)
    is_admin = [true, 'true'].include?(is_admin_claim)

    # Log for debugging
    role = is_admin ? 'admin' : 'user'
    Rails.logger.info "Role check for #{auth.info.email}: event_manager_admin claim = #{is_admin_claim.inspect} " \
                      "(type: #{is_admin_claim.class}), setting role to #{role}"

    # Return admin if claim is explicitly true, otherwise user (safe default)
    is_admin ? 'admin' : 'user'
  end
end
