class AddStockStatusToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :stock_status, :string
  end
end
