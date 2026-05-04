class Product < ApplicationRecord
    belongs_to :user
    has_many :price_records, dependent: :destroy

    validates :name, presence: true
    validates :category, presence: true
    # source_url is optional at the model level so legacy / seed / manual-only
    # products remain valid. The new-product form makes it required at the UI
    # level (HTML required + ProductsController#create blank check).
    validates :source_url,
              format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
              allow_blank: true

    def lowest_price
      price_records.minimum(:price)
    end

    def lowest_price_record
      price_records.order(:price).first
    end

    def latest_price
      price_records.order(recorded_at: :desc).first&.price
    end

    def latest_store
      price_records.order(recorded_at: :desc).first&.store_name
    end

    # Calculate price trend based on latest price vs historical average.
    # Returns :up (price increased), :down (price decreased), :stable (relatively unchanged), or nil
    def price_trend
      records = price_records.order(recorded_at: :asc)
      return nil if records.count < 2

      latest = records.last.price
      # Compare against average of all previous prices
      previous_avg = records[0...-1].map(&:price).sum / (records.count - 1).to_f

      diff_percent = ((latest - previous_avg) / previous_avg * 100).abs

      case
      when latest > previous_avg && diff_percent > 5
        :up
      when latest < previous_avg && diff_percent > 5
        :down
      else
        :stable
      end
    end

    # Human-readable price trend indicator
    def price_trend_emoji
      case price_trend
      when :up
        "📈"
      when :down
        "📉"
      when :stable
        "➡️"
      else
        "❓"
      end
    end

    # Trend description for accessibility
    def price_trend_description
      case price_trend
      when :up
        "Price is trending up"
      when :down
        "Price is trending down"
      when :stable
        "Price is stable"
      else
        "Not enough data to determine trend"
      end
    end
end
