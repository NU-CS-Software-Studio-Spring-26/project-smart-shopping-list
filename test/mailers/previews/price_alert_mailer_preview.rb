class PriceAlertMailerPreview < ActionMailer::Preview
  # Visit any of these previews in development at:
  #   http://localhost:3000/rails/mailers/price_alert_mailer
  #
  # Each preview uses the FIRST product in the DB that has at least one
  # price record. Seed your local DB first (bin/rails db:seed) and add a
  # product manually if needed.

  def price_drop_target_hit
    product, record = sample_product_with_record
    return placeholder("price_drop (target_hit)") if product.nil?

    product.target_price ||= record.price + 5
    PriceAlertMailer.price_drop(product, record, reasons: [ :target_hit ])
  end

  def price_drop_history_low
    product, record = sample_product_with_record
    return placeholder("price_drop (history_low)") if product.nil?

    PriceAlertMailer.price_drop(product, record, reasons: [ :history_low ])
  end

  def price_drop_both_reasons
    product, record = sample_product_with_record
    return placeholder("price_drop (both reasons)") if product.nil?

    product.target_price ||= record.price + 5
    PriceAlertMailer.price_drop(product, record, reasons: [ :target_hit, :history_low ])
  end

  private

  def sample_product_with_record
    record = PriceRecord.order(price: :asc).first
    [ record&.product, record ]
  end

  def placeholder(label)
    ActionMailer::Base.mail(
      to:      "preview@example.com",
      from:    "from@example.com",
      subject: "[#{label}] No product+record in DB to preview against"
    ) do |format|
      format.text { render plain: "Seed your local DB or add a product with a price first." }
    end
  end
end
