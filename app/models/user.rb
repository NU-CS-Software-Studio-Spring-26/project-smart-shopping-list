class User < ApplicationRecord
  class OauthError < StandardError; end

  PASSWORD_MIN_LENGTH = 8

  # Single source of truth for the password rules we can check live in the
  # browser. The registrations + reset forms render this list as a checklist,
  # and the password_strength Stimulus controller tests each rule by `key`
  # as the user types — so feedback is instant instead of waiting for submit.
  # (Email-containment and common-password checks stay server-side only.)
  PASSWORD_REQUIREMENTS = [
    { key: "length",     label: "At least #{PASSWORD_MIN_LENGTH} characters" },
    { key: "special",    label: "Includes a special character (! @ # …)" },
    { key: "no_repeats", label: "No character repeated 3+ times in a row" }
  ].freeze

  has_secure_password
  has_one_attached :avatar
  has_many :sessions, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :folders, dependent: :destroy

  attr_accessor :terms_accepted

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  AVATAR_MAX_BYTES = 5.megabytes
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp image/gif].freeze

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  validates :provider, length: { maximum: 50 }, allow_blank: true
  validates :uid, length: { maximum: 255 }, allow_blank: true
  validates :name, length: { maximum: 120 }, allow_blank: true
  validates :avatar_url,
            length: { maximum: 2_000 },
            format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
            allow_blank: true
  validates :uid, uniqueness: { scope: :provider }, if: -> { provider.present? && uid.present? }

  validates :password, length: { minimum: PASSWORD_MIN_LENGTH, message: "must be at least #{PASSWORD_MIN_LENGTH} characters" }, if: -> { password.present? }
  validate :password_strength, if: -> { password.present? && !oauth_user? }
  validate :terms_must_be_accepted, on: :create, unless: :oauth_user?
  validate :avatar_is_acceptable, if: -> { avatar.attached? }

  def oauth_user?
    provider.present? && uid.present?
  end

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end

  # Case-insensitive lookup — handles legacy rows saved before email
  # normalization, so Google sign-in can attach to an existing account.
  def self.find_by_email_address(email)
    normalized = normalize_email(email)
    return nil if normalized.blank?

    where("LOWER(email_address) = ?", normalized).first
  end

  def self.accounts_for_email(email)
    normalized = normalize_email(email)
    return none if normalized.blank?

    where("LOWER(email_address) = ?", normalized).order(:created_at)
  end

  # Find-or-create a User from an OmniAuth::AuthHash. Looks up by
  # (provider, uid) first so repeat sign-ins land on the same row, then by
  # email (case-insensitive) so users who originally signed up locally are
  # linked instead of getting a second account. If duplicate rows already
  # exist for the same email, their products are merged into one user.
  # New OAuth users get a random password that satisfies has_secure_password's
  # create-time presence validation; they sign in via the provider, not by
  # typing it. Raises User::OauthError on a missing email or validation
  # failure so OmniauthCallbacksController can surface a friendly message.
  def self.from_omniauth(auth)
    provider = auth.provider.to_s
    uid = auth.uid.to_s
    info = auth.info
    email = normalize_email(info.email)

    raise OauthError, "Google did not return an email address." if email.blank?

    oauth_user = find_by(provider: provider, uid: uid)
    email_matches = accounts_for_email(email).to_a
    related_users = (email_matches + [ oauth_user ].compact).uniq(&:id)

    user =
      case related_users.size
      when 0 then new(email_address: email)
      when 1 then related_users.first
      else merge_accounts!(related_users)
      end

    user.provider = provider
    user.uid = uid
    user.name = info.name if info.respond_to?(:name) && info.name.present?
    user.avatar_url = info.image if info.respond_to?(:image) && info.image.present?
    user.email_address = email
    user.password = generated_oauth_password(email) if user.password_digest.blank?
    user.password_confirmation = user.password if user.password_digest.blank?
    user.save!
    user
  rescue ActiveRecord::RecordInvalid => e
    raise OauthError, e.record.errors.full_messages.to_sentence
  end

  # Combine duplicate accounts that share the same email. Keeps the account
  # with the most products, preferring the original password registration
  # when tied, and moves products from the others before deleting them.
  def self.merge_accounts!(users)
    keep = users.max_by { |user| [ user.products.count, user.oauth_user? ? 0 : 1, -user.created_at.to_i ] }

    transaction do
      users.each do |duplicate|
        next if duplicate.id == keep.id

        duplicate.products.update_all(user_id: keep.id)
        duplicate.sessions.delete_all
        duplicate.destroy!
      end

      keep.update!(email_address: normalize_email(keep.email_address))
    end

    keep
  end

  private

  COMMON_PASSWORDS = %w[password password1 password123 12345678 qwerty123 letmein welcome].freeze

  def self.generated_oauth_password(email = nil)
    username = email.to_s.split("@").first.downcase
    loop do
      password = "Sso!9#{SecureRandom.alphanumeric(24)}"
      next if password.match?(/(.)\1{2,}/)
      next if username.present? && password.downcase.include?(username)

      return password
    end
  end

  def terms_must_be_accepted
    return if ActiveModel::Type::Boolean.new.cast(terms_accepted)

    errors.add(:terms_accepted, "must be accepted before creating an account")
  end

  def avatar_is_acceptable
    blob = avatar.blob
    return if blob.blank?

    unless AVATAR_CONTENT_TYPES.include?(blob.content_type.to_s)
      errors.add(:avatar, "must be a PNG, JPEG, WebP, or GIF image")
    end

    if blob.byte_size > AVATAR_MAX_BYTES
      errors.add(:avatar, "is too large (maximum is 5 MB)")
    end
  end

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
