class PriceAlerter
  # Decides whether the newly-created PriceRecord should fire a price-drop
  # email to the product's owner, and if so, enqueues the email and stamps
  # `products.last_alerted_at` so we don't repeat ourselves.
  #
  # An alert can fire for one of two non-exclusive reasons:
  #
  #   :target_hit   — the user set `products.target_price` and the new price
  #                   is at or below that threshold.
  #
  #   :history_low  — the new price is strictly lower than every previous
  #                   PriceRecord for this product. We only consider this
  #                   when there's at least one earlier record; the very
  #                   first price ever logged is not announced as "a new
  #                   low" because there's nothing to compare against.
  #
  # Both reasons can apply at once, in which case the email mentions both.
  #
  # We always respect a per-product cooldown (24h by default) to avoid
  # spamming users when a price walks steadily downward over a few days.
  # The check runs *before* we evaluate reasons so cooldown is cheap.
  #
  # This service is invoked from PriceRecord#after_create_commit, so any
  # path that creates a PriceRecord — scraped (PriceFetcher), manual entry
  # in PriceRecordsController, seed data, etc. — flows through here.
  COOLDOWN = 24.hours

  def self.call(price_record)
    new(price_record).call
  end

  def initialize(price_record)
    @price_record = price_record
    @product      = price_record.product
  end

  def call
    return :no_product       if @product.nil?
    return :missing_price    if @price_record.price.blank?
    return :cooldown_active  if @product.alert_cooldown_active?(window: COOLDOWN)

    reasons = compute_reasons
    return :no_reason if reasons.empty?

    PriceAlertMailer.price_drop(@product, @price_record, reasons: reasons).deliver_later
    @product.update_column(:last_alerted_at, Time.current)
    reasons
  end

  private

  # Returns an array of reason symbols, e.g. [:target_hit, :history_low].
  def compute_reasons
    reasons = []
    reasons << :target_hit   if target_hit?
    reasons << :history_low  if history_low?
    reasons
  end

  def target_hit?
    return false unless @product.target_price_alert_enabled?
    @price_record.price <= @product.target_price
  end

  # "Strictly lower than every other record" requires at least one other
  # record to compare against. We exclude the just-created record by id so
  # this works even though after_create_commit fires post-insert.
  def history_low?
    previous_min = @product.price_records
                           .where.not(id: @price_record.id)
                           .minimum(:price)
    return false if previous_min.nil?
    @price_record.price < previous_min
  end
end
