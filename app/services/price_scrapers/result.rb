module PriceScrapers
  Result = Struct.new(
    :price,        # BigDecimal or nil
    :currency,     # "USD" / "CAD" / nil
    :title,        # String or nil
    :image_url,    # String or nil
    :store_name,   # "Amazon" / "Target" / fallback host
    :fetched_at,   # Time
    :resolved_url, # final URL after retailer-specific normalization (e.g. Lululemon -md)
    keyword_init: true
  ) do
    def initialize(*)
      super
      self.fetched_at ||= Time.current
    end
  end
end
