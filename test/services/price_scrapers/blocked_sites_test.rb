require "test_helper"

class PriceScrapers::BlockedSitesTest < ActiveSupport::TestCase
  test "matches known blocked retailers across subdomains" do
    assert_equal "Lululemon",
      PriceScrapers::BlockedSites.label_for("https://shop.lululemon.com/p/shirt/eoz64nncho?color=1")
    assert_equal "Nordstrom",
      PriceScrapers::BlockedSites.label_for("https://www.nordstrom.com/s/thing/123")
    assert_equal "Free People",
      PriceScrapers::BlockedSites.label_for("https://freepeople.com/shop/x")
  end

  test "returns nil for sites we can fetch" do
    assert_nil PriceScrapers::BlockedSites.label_for("https://www.bestbuy.com/site/x.p")
    assert_nil PriceScrapers::BlockedSites.label_for("https://example.com/p/1")
  end

  test "does not match lookalike hosts" do
    assert_nil PriceScrapers::BlockedSites.label_for("https://notlululemon.com/p/1")
    assert_nil PriceScrapers::BlockedSites.label_for("https://lululemon.com.evil.test/p/1")
  end

  test "handles blank and invalid urls" do
    assert_nil PriceScrapers::BlockedSites.label_for(nil)
    assert_nil PriceScrapers::BlockedSites.label_for("")
    assert_nil PriceScrapers::BlockedSites.label_for("not a url")
  end

  test "blocked? mirrors label_for" do
    assert PriceScrapers::BlockedSites.blocked?("https://shop.lululemon.com/p/x")
    assert_not PriceScrapers::BlockedSites.blocked?("https://example.com/p/x")
  end
end
