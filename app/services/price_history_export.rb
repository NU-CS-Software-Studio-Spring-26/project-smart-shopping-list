require "csv"

class PriceHistoryExport
  HEADERS = [
    "Product",
    "Category",
    "Store",
    "Price",
    "Source",
    "Recorded at",
    "URL",
    "Notes"
  ].freeze

  def self.to_csv(product)
    new(product).to_csv
  end

  def initialize(product)
    @product = product
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADERS

      price_records.each do |record|
        csv << [
          product.name,
          product.category,
          record.store_name,
          format("%.2f", record.price),
          record.source.presence || "manual",
          record.recorded_at.iso8601,
          record.url,
          record.notes
        ]
      end
    end
  end

  private

  attr_reader :product

  def price_records
    product.price_records.order(recorded_at: :asc, id: :asc)
  end
end
