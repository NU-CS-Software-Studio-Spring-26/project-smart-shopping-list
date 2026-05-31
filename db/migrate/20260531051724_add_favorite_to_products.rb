class AddFavoriteToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :favorite, :boolean, default: false, null: false
    # Supports the per-user "favorites only" filter and favorites row.
    add_index :products, [ :user_id, :favorite ]
  end
end
