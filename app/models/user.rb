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
    user
  end

  def self.determine_role_from_auth(auth)
    # Check if Authentik sends the event_manager_admin claim
    is_admin = auth.extra&.raw_info&.event_manager_admin

    # Log for debugging
    Rails.logger.info "Authentik role check for #{auth.info.email}: event_manager_admin=#{is_admin.inspect}"

    # Return admin if claim is true, otherwise user
    is_admin == true ? 'admin' : 'user'
  end
end
