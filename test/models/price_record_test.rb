require "test_helper"

class PriceRecordTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  def setup
    @product = users(:one).products.create!(name: "Test Product", category: "Electronics")
    @record = PriceRecord.new(
      product: @product,
      price: 99.99,
      store_name: "Amazon",
      url: "https://www.amazon.com/test",
      recorded_at: Time.current
    )
  end

  test "valid price record" do
    assert @record.valid?
  end

  test "invalid without price" do
    @record.price = nil
    assert_not @record.valid?
  end

  test "invalid with zero price" do
    @record.price = 0
    assert_not @record.valid?
  end

  test "invalid with negative price" do
    @record.price = -5
    assert_not @record.valid?
  end

  test "invalid without store_name" do
    @record.store_name = ""
    assert_not @record.valid?
  end

  test "url is optional" do
    @record.url = nil
    assert @record.valid?
  end

  test "belongs to product" do
    assert_equal @product, @record.product
  end

  # --- Alert callback wiring ---
  #
  # These tests prove that creating a PriceRecord actually triggers the
  # PriceAlerter pipeline end-to-end. The cooldown / target / history-low
  # logic itself is exhaustively covered in PriceAlerterTest; here we only
  # care that the wiring fires.

  test "after_create_commit enqueues a price-drop email when target is hit" do
    PriceRecord.alerter_callback_enabled = true
    @product.update!(target_price: 100)

    # Seed an earlier record with the callback enabled — it's a brand-new
    # product so neither reason fires for this first record (no target hit
    # at $200, no history yet), so this :no_reason path is silent.
    @product.price_records.create!(price: 200, store_name: "Seed", recorded_at: 1.day.ago)

    assert_enqueued_emails 1 do
      @product.price_records.create!(price: 80, store_name: "X", recorded_at: Time.current)
    end
  end

  test "after_create_commit is silent when neither reason fires" do
    PriceRecord.alerter_callback_enabled = true
    # Default product: no target, no history. Creating the first record
    # should produce no email (PriceAlerter returns :no_reason).
    assert_no_enqueued_emails do
      @product.price_records.create!(price: 100, store_name: "X", recorded_at: Time.current)
    end
  end

  test "after_create_commit is silent when alerter_callback_enabled is false" do
    PriceRecord.alerter_callback_enabled = false
    @product.update!(target_price: 100)
    @product.price_records.create!(price: 200, store_name: "Seed", recorded_at: 1.day.ago)

    assert_no_enqueued_emails do
      @product.price_records.create!(price: 50, store_name: "X", recorded_at: Time.current)
    end
  ensure
    PriceRecord.alerter_callback_enabled = true
  end
end
