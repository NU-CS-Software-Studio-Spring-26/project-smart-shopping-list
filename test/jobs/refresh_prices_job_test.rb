require "test_helper"

class RefreshPricesJobTest < ActiveJob::TestCase
  setup do
    @product = products(:one)
    @product.update_columns(source_url: "https://www.example.com/p/123", last_fetched_at: 2.days.ago)
    @run = PriceRefreshRun.create!(
      triggered_by: "manual",
      status: "pending",
      batch_size: RefreshSchedule.batch_size,
      enqueued_at: Time.current
    )
  end

  test "perform calls refresh_batch with schedule-derived limit and records summary" do
    called_with = nil
    stub_method(PriceFetcher, :refresh_batch, ->(**kwargs) {
      called_with = kwargs
      {
        total: 1,
        batch_size: kwargs[:limit],
        attempted: 1,
        succeeded: 1,
        failed: 0,
        stale_remaining: 0,
        failures: [],
        duration: 0.1
      }
    }) do
      RefreshPricesJob.perform_now(@run.id)
    end

    assert_equal RefreshSchedule.batch_size, called_with[:limit]
    assert_equal RefreshSchedule.stale_after, called_with[:min_age]
    assert_equal 0, called_with[:sleep_between]

    @run.reload
    assert_equal "completed", @run.status
    assert_equal 1, @run.succeeded
    assert_not_nil @run.finished_at
  end

  test "perform skips when advisory lock is held" do
    lock_key = RefreshPricesJob::ADVISORY_LOCK_KEY
    holder = ActiveRecord::Base.connection_pool.checkout
    assert holder.select_value("SELECT pg_try_advisory_lock(#{lock_key})")

    called = false
    stub_method(PriceFetcher, :refresh_batch, ->(**_kwargs) { called = true }) do
      RefreshPricesJob.perform_now(@run.id)
    end
    refute called

    @run.reload
    assert_equal "skipped_overlap", @run.status
    assert_not_nil @run.finished_at
  ensure
    if defined?(holder) && holder
      holder.select_value("SELECT pg_advisory_unlock(#{lock_key})")
      ActiveRecord::Base.connection_pool.checkin(holder)
    end
  end
end
