class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :products, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  validates :password, length: { minimum: 8, message: "must be at least 8 characters" }, if: -> { password.present? }
  validate :password_strength, if: -> { password.present? && !oauth_user? }

  # Find-or-create a User from an OmniAuth::AuthHash. Called by
  # SessionsController#create_omniauth. Matches first on (provider, uid) so
  # repeat sign-ins always land on the same row, then falls back to the
  # email address so users who originally signed up locally can attach a
  # Google login later. New OAuth users get a random password that satisfies
  # has_secure_password's create-time presence validation; they sign in via
  # the provider, not by typing it.
  def self.from_omniauth(auth)
    return nil unless auth.respond_to?(:provider) && auth.respond_to?(:uid)

    user = find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_by(email_address: auth.info&.email&.downcase) if auth.info&.email.present?
    user ||= new(email_address: auth.info&.email)

    user.provider   = auth.provider
    user.uid        = auth.uid
    user.name       = auth.info&.name       if auth.info&.name.present?
    user.avatar_url = auth.info&.image      if auth.info&.image.present?

    if user.password_digest.blank?
      random = SecureRandom.urlsafe_base64(24) + "!Aa1"
      user.password = random
      user.password_confirmation = random
    end

    user.save
    user
  end

  def oauth_user?
    provider.present? && uid.present?
  end

  private

  COMMON_PASSWORDS = %w[password password1 password123 12345678 qwerty123 letmein welcome].freeze

  def password_strength
    pwd = password.to_s

    unless pwd.match?(/[^A-Za-z0-9]/)
      errors.add(:password, "must contain at least one special character (e.g. !, @, #)")
    end

    if pwd.match?(/(.)\1{2,}/)
      errors.add(:password, "must not contain three or more repeated characters in a row")
    end

    if email_address.present?
      username = email_address.split("@").first.downcase
      if pwd.downcase.include?(username)
        errors.add(:password, "must not contain your email address")
      end
    end

    if COMMON_PASSWORDS.include?(pwd.downcase)
      errors.add(:password, "is too common — please choose a more unique password")
    end
  end
end
