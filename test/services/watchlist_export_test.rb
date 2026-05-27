require "test_helper"
require "csv"

class WatchlistExportTest < ActiveSupport::TestCase
  test "exports watchlist summary rows" do
    product = products(:one)
    product.update!(tags_input: "gifts, urgent", target_price: 20)
    product.price_records.create!(price: 12.50, store_name: "Target", recorded_at: Time.current)

    csv = CSV.parse(WatchlistExport.to_csv([ product ]), headers: true)

    assert_equal "Product", csv.headers.first
    assert_equal "Sample Product One", csv.first["Product"]
    assert_equal "gifts, urgent", csv.first["Tags"]
    assert_equal "12.50", csv.first["Latest price"]
    assert_equal "20.00", csv.first["Target price"]
  end
end
