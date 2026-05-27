require "csv"

class WatchlistExport
  HEADERS = [
    "Product",
    "Category",
    "Tags",
    "Latest price",
    "Lowest price",
    "Target price",
    "Latest store",
    "Source URL",
    "Auto refresh",
    "Tracking since"
  ].freeze

  def self.to_csv(products)
    new(products).to_csv
  end

  def initialize(products)
    @products = products
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADERS

      products.each do |product|
        csv << [
          product.name,
          product.category,
          product.tags.join(", "),
          money(product.latest_price),
          money(product.lowest_price),
          money(product.target_price),
          product.latest_store,
          product.source_url,
          product.auto_refresh? ? "yes" : "no",
          product.created_at.iso8601
        ]
      end
    end
  end

  private

  attr_reader :products

  def money(value)
    return nil if value.blank?

    format("%.2f", value)
  end
end
