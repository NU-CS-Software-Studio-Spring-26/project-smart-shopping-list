class AddCatalogWithUrlToPriceRefreshRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :price_refresh_runs, :catalog_with_url, :integer
  end
end
