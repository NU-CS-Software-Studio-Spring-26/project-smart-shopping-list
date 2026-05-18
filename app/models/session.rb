class Session < ApplicationRecord
  EXPIRES_AFTER = 30.days

  belongs_to :user

  before_validation :set_default_expiration, on: :create

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  private

  def set_default_expiration
    self.expires_at ||= EXPIRES_AFTER.from_now
  end
end
