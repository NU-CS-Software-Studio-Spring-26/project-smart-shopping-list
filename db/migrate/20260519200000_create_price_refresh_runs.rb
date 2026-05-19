class CreatePriceRefreshRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :price_refresh_runs do |t|
      t.string :triggered_by, null: false, default: "unknown"
      t.string :status, null: false, default: "pending"
      t.integer :total_products
      t.integer :batch_size
      t.integer :attempted, null: false, default: 0
      t.integer :succeeded, null: false, default: 0
      t.integer :failed, null: false, default: 0
      t.integer :stale_remaining
      t.decimal :duration_seconds, precision: 8, scale: 1
      t.jsonb :failure_details, null: false, default: []
      t.text :error_message
      t.datetime :enqueued_at, null: false
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :price_refresh_runs, :enqueued_at
    add_index :price_refresh_runs, :status
  end
end
