require "test_helper"

class PriceScrapers::LululemonAdapterTest < ActiveSupport::TestCase
  def fixture(name)
    Rails.root.join("test/fixtures/scrapers", name).read
  end

  test "retries with -md suffix after HTTP 400 on legacy style id" do
    adapter = PriceScrapers::LululemonAdapter.new
    old = "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb?color=74136"
    expected = "https://shop.lululemon.com/p/ultralight-wovenair-jacket/dsn0kocspb-md?color=74136"
    calls = []

    html = fixture("json_ld_lululemon.html")

    adapter.define_singleton_method(:http_get) do |url, timeout:|
      calls << url
      if url == old
        raise PriceScrapers::PermanentError, "HTTP 400 from shop.lululemon.com"
      end

      Struct.new(:body, :code).new(html, 200)
    end

    result = adapter.fetch(old)
    assert_equal BigDecimal("118.00"), result.price
    assert_equal expected, result.resolved_url
    assert_equal [ old, expected ], calls
  end
end
