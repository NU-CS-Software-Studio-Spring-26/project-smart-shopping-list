class CreatePriceRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :price_records do |t|
      t.references :product, null: false, foreign_key: true
      t.decimal :price
      t.string :store_name
      t.string :url
      t.datetime :recorded_at
      t.text :notes

      t.timestamps
    end
  end
end
