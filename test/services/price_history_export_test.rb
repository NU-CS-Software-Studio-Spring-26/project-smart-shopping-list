require "test_helper"
require "csv"

class PriceHistoryExportTest < ActiveSupport::TestCase
  test "exports price records in chronological order" do
    product = products(:one)
    product.price_records.destroy_all

    product.price_records.create!(
      price: 12.34,
      store_name: "Target",
      source: "manual",
      recorded_at: Time.zone.parse("2026-05-02 10:00:00"),
      notes: "Later check"
    )
    product.price_records.create!(
      price: 10.99,
      store_name: "Amazon",
      source: "scraped",
      recorded_at: Time.zone.parse("2026-05-01 10:00:00"),
      url: "https://example.com/item",
      notes: "First check"
    )

    csv = CSV.parse(PriceHistoryExport.to_csv(product), headers: true)

    assert_equal "Amazon", csv.first["Store"]
    assert_equal "10.99", csv.first["Price"]
    assert_equal "Target", csv[1]["Store"]
    assert_equal "12.34", csv[1]["Price"]
  end
end
