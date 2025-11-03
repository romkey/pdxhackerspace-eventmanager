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
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = Devise.friendly_token[0, 20]
    end
  end
end
