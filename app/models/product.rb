class Product < ApplicationRecord
    # Column caps mirror the DB check constraints added in
    # HardenProductAndPriceRecordConstraints. Scraped Amazon / Target / etc.
    # titles routinely run past 200 chars; rather than reject the save and
    # show a validation error, we silently truncate in a before_validation
    # so every save path (scraper, manual form, seeds) stays within bounds.
    NAME_LIMIT        = 140
    CATEGORY_LIMIT    = 80
    DESCRIPTION_LIMIT = 1_000
    TAG_LIMIT         = 32
    MAX_TAGS          = 8

    # Normalized stock states the scraper can record. nil means "unknown /
    # not reported by the page" (the default for manual and legacy products).
    STOCK_STATUSES = %w[in_stock out_of_stock].freeze

    belongs_to :user
    has_many :price_records, dependent: :destroy
    has_many :folder_products, dependent: :destroy
    has_many :folders, through: :folder_products

    # When the category select is set to "Other", the form sends the user's
    # typed-in category name here. apply_custom_category folds it into
    # `category` before validation/truncation so niche categories are saved
    # and remain filterable like any other.
    attr_accessor :custom_category

    before_validation :apply_custom_category
    before_validation :truncate_long_text_fields
    before_validation :normalize_tags
    before_validation :canonicalize_lululemon_source_url
    before_save :clear_fetch_error_when_not_auto_refreshing
    before_validation :disable_auto_refresh_without_url, on: :update

    validates :name, presence: true
    validates :name, length: { maximum: NAME_LIMIT }
    validates :category, presence: true
    validates :category, length: { maximum: CATEGORY_LIMIT }
    validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_blank: true
    validate :tags_are_reasonable
    validates :image_url,
              length: { maximum: 2_000 },
              format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
              allow_blank: true
    # source_url is optional at the model level so legacy / seed / manual-only
    # products remain valid. The new-product form makes it required at the UI
    # level (HTML required + ProductsController#create blank check).
    validates :source_url,
              length: { maximum: 2_000 },
              format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
              allow_blank: true
    # target_price is opt-in: a nil value just means "no alert configured".
    # When set, it must be a positive number. We cap it at 10 million to keep
    # the column inside its decimal(10,2) precision.
    validates :target_price,
              numericality: { greater_than: 0, less_than_or_equal_to: 10_000_000 },
              allow_nil: true
    validates :stock_status, inclusion: { in: STOCK_STATUSES }, allow_nil: true

    # True iff the owner has asked to be alerted when the price hits or
    # drops below `target_price`. Used by PriceAlerter to decide whether to
    # bother running the rest of the alert evaluation.
    def target_price_alert_enabled?
      target_price.present?
    end

    # Don't email the user more than once per `window`. The 24-hour default
    # matches PriceAlerter's expectations and gives us room to lengthen the
    # window later if users complain about noise.
    def alert_cooldown_active?(window: 24.hours)
      last_alerted_at.present? && last_alerted_at > window.ago
    end

    # Used by the product detail / index views to decide whether to render
    # the "🎉 Price alert triggered" banner / card chip. Defaults to 7 days
    # so the banner stays around long enough for the user to actually see
    # the deal but doesn't linger forever.
    def recent_alert?(window: 7.days)
      last_alerted_at.present? && last_alerted_at > window.ago
    end

    # Best-effort lookup of the PriceRecord whose creation fired the most
    # recent alert. PriceAlerter stamps `last_alerted_at = Time.current`
    # right after writing the PriceRecord, so the trigger record is the
    # latest one whose `recorded_at` is at or before that stamp.
    def alert_trigger_record
      return nil if last_alerted_at.blank?
      price_records.where("recorded_at <= ?", last_alerted_at)
                   .order(recorded_at: :desc)
                   .first
    end

    # --- Stock status -----------------------------------------------------

    def stock_known?
      stock_status.present?
    end

    def in_stock?
      stock_status == "in_stock"
    end

    def out_of_stock?
      stock_status == "out_of_stock"
    end

    # Short human label for the UI, or nil when stock is unknown.
    def stock_status_label
      case stock_status
      when "in_stock"     then "In stock"
      when "out_of_stock" then "Out of stock"
      end
    end

    def lowest_price
      # Reuse the preloaded association (e.g. reports/index eager-loads
      # price_records) instead of issuing a fresh MIN(price) query per product.
      if price_records.loaded?
        price_records.filter_map(&:price).min
      else
        price_records.minimum(:price)
      end
    end

    def lowest_price_record
      price_records.order(:price).first
    end

    # True when the product has at least one recorded price. Gates the
    # price-history exports (CSV/PDF) so we never hand back an empty file.
    def price_history?
      if price_records.loaded?
        price_records.any?
      else
        price_records.exists?
      end
    end

    def latest_price
      newest_price_record&.price
    end

    def latest_store
      newest_price_record&.store_name
    end

    # Most recent PriceRecord. Uses the preloaded association when available so
    # callers that eager-load price_records don't trigger an N+1.
    def newest_price_record
      if price_records.loaded?
        price_records.max_by(&:recorded_at)
      else
        price_records.order(recorded_at: :desc).first
      end
    end

    # Calculate price trend based on latest price vs historical average.
    # Returns :up (price increased), :down (price decreased), :stable (relatively unchanged), or nil
    def price_trend
      records = if price_records.loaded?
        price_records.sort_by(&:recorded_at)
      else
        price_records.order(recorded_at: :asc).to_a
      end
      return nil if records.size < 2

      latest = records.last.price
      # Compare against average of all previous prices
      previous_avg = records[0...-1].sum(&:price) / (records.size - 1).to_f

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

    # User-flagged favorites, surfaced in the favorites row and "favorites only"
    # filter on the products index.
    scope :favorited, -> { where(favorite: true) }

    # Products with a source_url present (includes load-test / seed rows).
    scope :with_trackable_url, -> { where.not(source_url: [ nil, "" ]) }

    # Subset whose URLs point at real product pages we can scrape. Excludes:
    #   - example.com placeholders (pagination stress-test account)
    #   - retailer /search? URLs used by db/seeds.rb for volume, not PDPs
    scope :scrapeable, -> {
      with_trackable_url
        .where.not("source_url ILIKE ?", "%example.com%")
        .where.not("source_url ILIKE ?", "%/search?%")
        .where.not("source_url ILIKE ?", "%/s?k=%")
    }

    # Scrapeable products with auto_refresh enabled — cron and admin refresh
    # skip manual-only trackers (auto_refresh: false).
    scope :refreshable, -> { scrapeable.where(auto_refresh: true) }

    # Stable identifier for the Pagy load-test user (seeds / rake tasks).
    PAGINATION_TEST_EMAIL = "paginationtest@example.com"

    def self.scrape_excluded?(url)
      u = url.to_s
      return true if u.blank?
      return true if u.include?("example.com")
      return true if u.match?(%r{/search[?]}i) || u.match?(%r{/s[?]k=}i)

      false
    end

    def scrapeable?
      source_url.present? && !self.class.scrape_excluded?(source_url)
    end

    def tags_input
      defined?(@tags_input) ? @tags_input : tags.join(", ")
    end

    def tags_input=(value)
      @tags_input = value
    end

    # Only surface cron / "Fetch latest" failures when we actually attempt
    # automatic refresh. Manual-only products should not show REFRESH FAILED.
    def show_refresh_failure?
      auto_refresh? && last_fetch_error.present?
    end

    private

    # If the user chose "Other" and typed a custom category, use that instead.
    # No-op for predefined categories or a blank custom value (stays "Other").
    def apply_custom_category
      return unless category.to_s.strip == "Other"

      custom = custom_category.to_s.strip
      self.category = custom if custom.present?
    end

    def disable_auto_refresh_without_url
      return if source_url.present?

      self.auto_refresh = false
      self.last_fetch_error = nil
    end

    def clear_fetch_error_when_not_auto_refreshing
      return if auto_refresh?

      self.last_fetch_error = nil
    end

    def normalize_tags
      raw_tags = if defined?(@tags_input)
        @tags_input.to_s.split(",")
      else
        tags
      end

      self.tags = Array(raw_tags)
        .map { |tag| tag.to_s.strip.downcase }
        .reject(&:blank?)
        .uniq
        .first(MAX_TAGS)
    end

    def tags_are_reasonable
      tags.each do |tag|
        next if tag.length <= TAG_LIMIT

        errors.add(:tags, "must be #{TAG_LIMIT} characters or fewer")
      end
    end

    # Trim scraped/oversized text to the column caps before validations
    # run so a 250-char Amazon title never causes a save to fail. An
    # ellipsis marker is appended to make truncation visible to the user.
    def truncate_long_text_fields
      truncate_field(:name,        NAME_LIMIT)
      truncate_field(:category,    CATEGORY_LIMIT)
      truncate_field(:description, DESCRIPTION_LIMIT)
    end

    def truncate_field(attr, limit)
      value = self[attr]
      return if value.blank?
      return if value.length <= limit

      self[attr] = value[0, limit - 1].rstrip + "…"
    end

    def canonicalize_lululemon_source_url
      return if source_url.blank?
      return unless PriceScrapers::LululemonUrl.host?(source_url)

      canonical = PriceScrapers::LululemonUrl.upgrade_source_url!(source_url)
      self.source_url = canonical if canonical != source_url
    end
end
