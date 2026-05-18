require "test_helper"

class PriceAlertMailerTest < ActionMailer::TestCase
  setup do
    @user    = users(:one)
    @product = @user.products.create!(
      name:         "Sony WH-1000XM5",
      category:     "Electronics",
      target_price: 250
    )
    @record  = @product.price_records.build(
      price:       199.99,
      store_name:  "Best Buy",
      recorded_at: Time.current
    )
    # Avoid firing the after_create_commit alerter during arrangement.
    PriceRecord.alerter_callback_enabled = false
    @record.save!
  end

  teardown do
    PriceRecord.alerter_callback_enabled = true
  end

  test "subject leads with target_hit when that reason is present" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :target_hit, :history_low ])
    assert_match(/target price was hit/i, email.subject)
    assert_match(/Sony WH-1000XM5/, email.subject)
  end

  test "subject falls back to history_low when only that reason is present" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :history_low ])
    assert_match(/new all-time low/i, email.subject)
    assert_match(/Sony WH-1000XM5/, email.subject)
  end

  test "subject is a generic price update when no specific reason is given" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [])
    assert_match(/Price update on/i, email.subject)
  end

  test "email is addressed to the product owner" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :target_hit ])
    assert_equal [ @user.email_address ], email.to
  end

  test "body shows the new price and store name in both HTML and text parts" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :target_hit ])
    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |body|
      assert_match(/199\.99/, body, "expected the new price in #{body.lines.first}")
      assert_match(/Best Buy/, body, "expected the store name in #{body.lines.first}")
    end
  end

  test "target_hit line appears when reason includes :target_hit and mentions the target value" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :target_hit ])
    body  = email.html_part.body.to_s
    assert_match(/250/, body, "expected the target value to appear")
    assert_match(/target price/i, body)
  end

  test "history_low line appears when reason includes :history_low" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :history_low ])
    body  = email.html_part.body.to_s
    assert_match(/all-time low/i, body)
  end

  test "history_low line is omitted when that reason is not present" do
    email = PriceAlertMailer.price_drop(@product, @record, reasons: [ :target_hit ])
    body  = email.html_part.body.to_s
    refute_match(/all-time low/i, body)
  end
end
