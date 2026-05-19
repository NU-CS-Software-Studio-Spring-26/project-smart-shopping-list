class RefreshPricesJob < ApplicationJob
  queue_as :default

  # PostgreSQL advisory lock — prevents overlapping batches when a scrape
  # run outlasts the cron interval. No Redis required.
  ADVISORY_LOCK_KEY = 0x5052_4943_45 # "PRICE"

  def perform(refresh_run_id)
    run = PriceRefreshRun.find(refresh_run_id)
    run.update!(status: "running", started_at: Time.current)

    unless acquire_lock
      run.update!(
        status: "skipped_overlap",
        total_products: Product.scrapeable.count,
        batch_size: RefreshSchedule.batch_size,
        finished_at: Time.current
      )
      Rails.logger.warn("[RefreshPricesJob] skipped_due_to_overlap — previous batch still running")
      return
    end

    begin
      limit = RefreshSchedule.batch_size
      summary = PriceFetcher.refresh_batch(
        limit: limit,
        min_age: RefreshSchedule.stale_after,
        sleep_between: 0
      )
      run.apply_summary!(summary)
      Rails.logger.info("[RefreshPricesJob] run=#{run.id} #{summary.inspect}")
    rescue StandardError => e
      run.update!(
        status: "failed",
        error_message: e.message.to_s.first(500),
        finished_at: Time.current
      )
      raise
    ensure
      release_lock
    end
  end

  private

  def acquire_lock
    ActiveRecord::Base.connection.select_value(
      "SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_KEY})"
    )
  end

  def release_lock
    ActiveRecord::Base.connection.select_value(
      "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_KEY})"
    )
  end
end
