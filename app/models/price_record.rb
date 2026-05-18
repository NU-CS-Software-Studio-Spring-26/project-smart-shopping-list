class PriceRecord < ApplicationRecord
  belongs_to :product

  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :store_name, presence: true, length: { maximum: 120 }
  validates :recorded_at, presence: true
  validates :notes, length: { maximum: 1_000 }, allow_blank: true
  validates :url,
            allow_blank: true,
            length: { maximum: 2_000 },
            format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" }

  before_validation :set_recorded_at

  # Fire price-drop alerts after the row is durably committed so we never
  # send an email for a record that ultimately got rolled back by an outer
  # transaction. PriceAlerter is the sole owner of the "should we email?"
  # decision (cooldown, target_hit, history_low) — this callback just
  # delegates and never raises so a flaky mailer can't break product
  # creation or PriceFetcher.refresh_all.
  #
  # alerter_callback_enabled is a class-level kill switch so tests can
  # arrange fixtures without firing the alert pipeline. In production it
  # stays true; doubles as an emergency "stop sending alerts" lever.
  class_attribute :alerter_callback_enabled, default: true

  after_create_commit :run_price_alerter, if: :alerter_callback_enabled

  private

  def set_recorded_at
    self.recorded_at ||= Time.current
  end

  def run_price_alerter
    PriceAlerter.call(self)
  rescue StandardError => e
    Rails.logger.warn("[PriceRecord##{id}] PriceAlerter raised #{e.class}: #{e.message}")
  end
end
