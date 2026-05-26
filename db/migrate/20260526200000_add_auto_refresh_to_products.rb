class AddAutoRefreshToProducts < ActiveRecord::Migration[8.1]
  def up
    add_column :products, :auto_refresh, :boolean, null: false, default: true

    # Products with only manual price history were never part of the auto-
    # refresh workflow; clear stale cron errors so the UI stops saying
    # "REFRESH FAILED" forever.
    execute <<~SQL.squish
      UPDATE products
      SET auto_refresh = false, last_fetch_error = NULL
      WHERE last_fetch_error IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM price_records
          WHERE price_records.product_id = products.id
            AND price_records.source = 'scraped'
        )
    SQL
  end

  def down
    remove_column :products, :auto_refresh
  end
end
