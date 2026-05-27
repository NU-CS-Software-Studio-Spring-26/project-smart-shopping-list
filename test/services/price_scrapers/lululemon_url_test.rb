require "test_helper"

class PriceScrapers::LululemonUrlTest < ActiveSupport::TestCase
  test "md_style_fallback appends -md to bare style id" do
    old = "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb?color=74136"
    assert_equal "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb-md?color=74136",
                 PriceScrapers::LululemonUrl.md_style_fallback(old)
  end

  test "md_style_fallback is nil when style id already has a suffix" do
    url = "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb-md"
    assert_nil PriceScrapers::LululemonUrl.md_style_fallback(url)
  end

  test "candidates returns original then fallback" do
    old = "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb"
    assert_equal [
      old,
      "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb-md"
    ], PriceScrapers::LululemonUrl.candidates(old)
  end

  test "md_style_fallback leaves mixed-case style ids unchanged" do
    url = "https://shop.lululemon.com/p/everywhere-belt-bag-1L/LU9CBHS"
    assert_nil PriceScrapers::LululemonUrl.md_style_fallback(url)
  end
end
