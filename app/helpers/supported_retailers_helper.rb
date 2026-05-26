module SupportedRetailersHelper
  # badge: :tested (seed catalog / fixtures), :dedicated, :manual, :limited
  RetailerEntry = Data.define(:name, :domain, :hint, :badge, :priority)

  TESTED_RETAILERS = [
    RetailerEntry.new("Lululemon", "shop.lululemon.com",
                      "Primary demo site · 5 catalog URLs · JSON-LD fixture tests", :tested, 0),
    RetailerEntry.new("Amazon", "amazon.com",
                      "Dedicated scraper · 18 catalog URLs · all regional TLDs", :dedicated, 1),
    RetailerEntry.new("Best Buy", "bestbuy.com", "14 catalog URLs · electronics & appliances", :tested, 2),
    RetailerEntry.new("Walmart", "walmart.com", "5 catalog URLs · general merchandise", :tested, 3),
    RetailerEntry.new("Apple Store", "apple.com", "3 catalog URLs · Apple hardware", :tested, 4),
    RetailerEntry.new("Newegg", "newegg.com", "2 catalog URLs · PC parts & tech", :tested, 5),
    RetailerEntry.new("Nike", "nike.com", "1 catalog URL · athletic wear", :tested, 6),
    RetailerEntry.new("Adidas", "adidas.com", "1 catalog URL · athletic wear", :tested, 7),
    RetailerEntry.new("Costco", "costco.com", "1 catalog URL · warehouse club", :tested, 8),
    RetailerEntry.new("Home Depot", "homedepot.com", "1 catalog URL · home improvement", :tested, 9),
    RetailerEntry.new("Lowe's", "lowes.com", "1 catalog URL · home improvement", :tested, 10),
    RetailerEntry.new("B&H Photo", "bhphotovideo.com", "1 catalog URL · cameras & pro gear", :tested, 11),
    RetailerEntry.new("Etsy", "etsy.com", "1 catalog URL · marketplace & handmade", :tested, 12),
    RetailerEntry.new("IKEA", "ikea.com", "1 catalog URL · furniture & home", :tested, 13),
    RetailerEntry.new("Macy's", "macys.com", "1 catalog URL · department store", :tested, 14),
    RetailerEntry.new("REI", "rei.com", "1 catalog URL · outdoor gear", :tested, 15)
  ].freeze

  # JSON-LD / OG / microdata expected, but not in our seed catalog yet.
  AUTO_RETAILERS = [
    RetailerEntry.new("Kohl's", "kohls.com", "Standard JSON-LD on most PDPs", :auto, 20),
    RetailerEntry.new("GameStop", "gamestop.com", "Standard JSON-LD on most PDPs", :auto, 21),
    RetailerEntry.new("CVS", "cvs.com", "Standard JSON-LD on many PDPs", :auto, 22),
    RetailerEntry.new("Walgreens", "walgreens.com", "Standard JSON-LD on many PDPs", :auto, 23),
    RetailerEntry.new("Staples", "staples.com", "Standard JSON-LD on most PDPs", :auto, 24),
    RetailerEntry.new("Office Depot", "officedepot.com", "Standard JSON-LD on most PDPs", :auto, 25),
    RetailerEntry.new("Chewy", "chewy.com", "Standard JSON-LD on most PDPs", :auto, 26),
    RetailerEntry.new("Petco", "petco.com", "Standard JSON-LD on most PDPs", :auto, 27),
    RetailerEntry.new("Ulta", "ulta.com", "Standard JSON-LD on most PDPs", :auto, 28),
    RetailerEntry.new("Bed Bath & Beyond", "bedbathandbeyond.com", "Standard JSON-LD when available", :auto, 29),
    RetailerEntry.new("Wayfair", "wayfair.com", "Standard JSON-LD on most PDPs", :auto, 30),
    RetailerEntry.new("Overstock", "overstock.com", "Standard JSON-LD on most PDPs", :auto, 31),
    RetailerEntry.new("Shopify stores", "*.myshopify.com", "OG meta + microdata fallback", :auto, 32)
  ].freeze

  MANUAL_RETAILERS = [
    RetailerEntry.new("Target", "target.com",
                      "Save the link & image; log prices manually until auto-fetch returns", :manual, 40),
    RetailerEntry.new("eBay", "ebay.com",
                      "Listings vary — manual price entry is most reliable", :manual, 41)
  ].freeze

  LIMITED_RETAILERS = [
    RetailerEntry.new("Nordstrom", "nordstrom.com", "Cloudflare · often 403 from cloud IPs", :limited, 50),
    RetailerEntry.new("Sephora", "sephora.com", "Cloudflare · often 403 from cloud IPs", :limited, 51),
    RetailerEntry.new("ASOS", "asos.com", "Cloudflare · often 403 from cloud IPs", :limited, 52),
    RetailerEntry.new("ZARA", "zara.com", "Price sometimes loads only after JavaScript", :limited, 53),
    RetailerEntry.new("H&M", "hm.com", "Price sometimes loads only after JavaScript", :limited, 54),
    RetailerEntry.new("Urban Outfitters", "urbanoutfitters.com", "PerimeterX · datacenter IP blocks", :limited, 55),
    RetailerEntry.new("Free People", "freepeople.com", "PerimeterX · datacenter IP blocks", :limited, 56),
    RetailerEntry.new("Anthropologie", "anthropologie.com", "PerimeterX · datacenter IP blocks", :limited, 57)
  ].freeze

  BADGE_LABELS = {
    tested: "Tested",
    dedicated: "Dedicated",
    auto: "Auto",
    manual: "Manual",
    limited: "Limited"
  }.freeze

  def tested_retailers
    TESTED_RETAILERS.sort_by(&:priority)
  end

  def auto_fetch_retailers
    AUTO_RETAILERS.sort_by(&:priority)
  end

  def manual_retailers
    MANUAL_RETAILERS.sort_by(&:priority)
  end

  def limited_retailers
    LIMITED_RETAILERS.sort_by(&:priority)
  end

  def retailer_badge_label(badge)
    BADGE_LABELS.fetch(badge)
  end

  def retailer_badge_class(badge)
    "pt-retailer-badge-#{badge}"
  end
end
