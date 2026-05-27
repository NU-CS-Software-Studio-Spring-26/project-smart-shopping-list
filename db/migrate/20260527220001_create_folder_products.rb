class CreateFolderProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :folder_products do |t|
      t.references :folder, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true

      t.timestamps
    end

    add_index :folder_products, [ :folder_id, :product_id ], unique: true
  end
end
