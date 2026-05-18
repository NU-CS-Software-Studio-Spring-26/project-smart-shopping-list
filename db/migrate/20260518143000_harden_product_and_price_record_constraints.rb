class HardenProductAndPriceRecordConstraints < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE products SET name = 'Untitled product' WHERE name IS NULL OR name = ''"
    execute "UPDATE products SET category = 'Other' WHERE category IS NULL OR category = ''"
    execute "UPDATE price_records SET price = 0.01 WHERE price IS NULL OR price <= 0"
    execute "UPDATE price_records SET store_name = 'Unknown' WHERE store_name IS NULL OR store_name = ''"
    execute "UPDATE price_records SET recorded_at = CURRENT_TIMESTAMP WHERE recorded_at IS NULL"
    execute "UPDATE products SET name = left(name, 140) WHERE char_length(name) > 140"
    execute "UPDATE products SET category = left(category, 80) WHERE char_length(category) > 80"
    execute "UPDATE products SET description = left(description, 1000) WHERE description IS NOT NULL AND char_length(description) > 1000"
    execute "UPDATE products SET source_url = left(source_url, 2000) WHERE source_url IS NOT NULL AND char_length(source_url) > 2000"
    execute "UPDATE products SET image_url = left(image_url, 2000) WHERE image_url IS NOT NULL AND char_length(image_url) > 2000"
    execute "UPDATE price_records SET store_name = left(store_name, 120) WHERE char_length(store_name) > 120"
    execute "UPDATE price_records SET notes = left(notes, 1000) WHERE notes IS NOT NULL AND char_length(notes) > 1000"
    execute "UPDATE price_records SET url = left(url, 2000) WHERE url IS NOT NULL AND char_length(url) > 2000"

    change_column_null :products, :name, false
    change_column_null :products, :category, false

    change_column_null :price_records, :price, false
    change_column_null :price_records, :store_name, false
    change_column_null :price_records, :recorded_at, false

    add_check_constraint :price_records, "price > 0", name: "price_records_price_positive"
    add_check_constraint :products, "char_length(name) <= 140", name: "products_name_length"
    add_check_constraint :products, "char_length(category) <= 80", name: "products_category_length"
    add_check_constraint :products, "description IS NULL OR char_length(description) <= 1000", name: "products_description_length"
    add_check_constraint :products, "source_url IS NULL OR char_length(source_url) <= 2000", name: "products_source_url_length"
    add_check_constraint :products, "image_url IS NULL OR char_length(image_url) <= 2000", name: "products_image_url_length"
    add_check_constraint :price_records, "char_length(store_name) <= 120", name: "price_records_store_name_length"
    add_check_constraint :price_records, "notes IS NULL OR char_length(notes) <= 1000", name: "price_records_notes_length"
    add_check_constraint :price_records, "url IS NULL OR char_length(url) <= 2000", name: "price_records_url_length"

    add_index :products, :category
    add_index :products, :created_at
    add_index :price_records, :recorded_at
  end

  def down
    remove_index :price_records, :recorded_at
    remove_index :products, :created_at
    remove_index :products, :category

    remove_check_constraint :price_records, name: "price_records_url_length"
    remove_check_constraint :price_records, name: "price_records_notes_length"
    remove_check_constraint :price_records, name: "price_records_store_name_length"
    remove_check_constraint :products, name: "products_image_url_length"
    remove_check_constraint :products, name: "products_source_url_length"
    remove_check_constraint :products, name: "products_description_length"
    remove_check_constraint :products, name: "products_category_length"
    remove_check_constraint :products, name: "products_name_length"
    remove_check_constraint :price_records, name: "price_records_price_positive"

    change_column_null :price_records, :recorded_at, true
    change_column_null :price_records, :store_name, true
    change_column_null :price_records, :price, true

    change_column_null :products, :category, true
    change_column_null :products, :name, true
  end
end
