require "test_helper"

class PriceAlerterTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @user    = users(:one)
    @product = @user.products.create!(name: "Test Product", category: "Electronics")
    # Suppress the after_create_commit callback so each test can arrange
    # records and invoke PriceAlerter.call explicitly. The callback path
    # itself is covered separately in test/models/price_record_test.rb.
    PriceRecord.alerter_callback_enabled = false
  end

  teardown do
    PriceRecord.alerter_callback_enabled = true
  end

  # ---------- no-op cases ----------

  test "returns :no_reason when the product has no target and no history" do
    record = build_record(price: 100)
    record.save!
    assert_no_enqueued_emails do
      assert_equal :no_reason, PriceAlerter.call(record)
    end
  end

  test "returns :no_reason when new price is above target and not a history low" do
    @product.update!(target_price: 50)
    create_record!(price: 30)
    record = create_record!(price: 60)

    assert_no_enqueued_emails do
      assert_equal :no_reason, PriceAlerter.call(record)
    end
  end

  test "the very first record on a product is NOT treated as a history low" do
    # Otherwise every newly-tracked product would fire 'new all-time low!'
    # immediately on creation, which is meaningless and noisy.
    record = create_record!(price: 1)

    assert_no_enqueued_emails do
      assert_equal :no_reason, PriceAlerter.call(record)
    end
  end

  # ---------- target_hit ----------

  test "target_hit fires when new price is at or below the target (boundary is <=)" do
    @product.update!(target_price: 100)
    create_record!(price: 150)
    record = create_record!(price: 100)

    assert_enqueued_emails 1 do
      reasons = Array(PriceAlerter.call(record))
      assert_includes reasons, :target_hit
    end
  end

  test "target_hit does NOT fire when target_price is nil" do
    @product.update!(target_price: nil)
    create_record!(price: 120)
    record = create_record!(price: 50)

    reasons = Array(PriceAlerter.call(record))
    refute_includes reasons, :target_hit
  end

  test "target_hit does NOT fire when new price is above the target" do
    @product.update!(target_price: 50)
    create_record!(price: 200)
    record = create_record!(price: 100)

    reasons = Array(PriceAlerter.call(record))
    refute_includes reasons, :target_hit
  end

  # ---------- history_low ----------

  test "history_low fires when new price is strictly lower than every previous record" do
    create_record!(price: 100)
    create_record!(price: 80)
    record = create_record!(price: 70)

    assert_enqueued_emails 1 do
      reasons = Array(PriceAlerter.call(record))
      assert_includes reasons, :history_low
    end
  end

  test "history_low requires strict < (a tie with the existing minimum does NOT re-trigger)" do
    create_record!(price: 100)
    create_record!(price: 80)
    record = create_record!(price: 80) # equal to the current minimum

    reasons = Array(PriceAlerter.call(record))
    refute_includes reasons, :history_low
  end

  # ---------- both reasons together ----------

  test "both reasons appear when a price hits target AND is a new history low" do
    @product.update!(target_price: 100)
    create_record!(price: 120)
    record = create_record!(price: 95)

    reasons = Array(PriceAlerter.call(record))
    assert_includes reasons, :target_hit
    assert_includes reasons, :history_low
  end

  # ---------- cooldown ----------

  test "cooldown blocks an alert that would otherwise fire" do
    @product.update!(target_price: 100, last_alerted_at: 1.hour.ago)
    create_record!(price: 120)
    record = create_record!(price: 50)

    assert_no_enqueued_emails do
      assert_equal :cooldown_active, PriceAlerter.call(record)
    end
  end

  test "an alert older than 24 hours does NOT block a new alert" do
    @product.update!(target_price: 100, last_alerted_at: 25.hours.ago)
    create_record!(price: 120)
    record = create_record!(price: 50)

    assert_enqueued_emails 1 do
      reasons = Array(PriceAlerter.call(record))
      assert_includes reasons, :target_hit
    end
  end

  test "firing an alert stamps last_alerted_at" do
    @product.update!(target_price: 100)
    create_record!(price: 120)
    record = create_record!(price: 90)
    assert_nil @product.last_alerted_at

    PriceAlerter.call(record)

    assert_not_nil @product.reload.last_alerted_at
    assert @product.alert_cooldown_active?
  end

  # ---------- defensive ----------

  test "missing price returns :missing_price and sends nothing" do
    # Built (not saved) so we sidestep the presence validation but still
    # exercise the early-return inside PriceAlerter.
    record = build_record(price: nil)

    assert_no_enqueued_emails do
      assert_equal :missing_price, PriceAlerter.call(record)
    end
  end

  private

  def build_record(price:)
    @product.price_records.build(
      price:       price,
      store_name:  "TestStore",
      recorded_at: Time.current
    )
  end

  def create_record!(price:)
    @product.price_records.create!(
      price:       price,
      store_name:  "TestStore",
      recorded_at: Time.current
    )
  end
end
