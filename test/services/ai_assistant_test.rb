require "test_helper"

class AiAssistantTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def product_with_prices(name, prices)
    product = @user.products.create!(name: name, category: "Electronics")
    base = 10.days.ago
    prices.each_with_index do |price, i|
      product.price_records.create!(price: price, store_name: "Store", recorded_at: base + i.days)
    end
    product
  end

  # Force the deterministic heuristic path so these tests never depend on a
  # live LLM (and stay stable regardless of any local API-key env).
  def with_ai_disabled(&block)
    stub_method(LlmClient, :enabled?, -> { false }, &block)
  end

  test "does not claim 'lowest ever' for a product with only one logged price" do
    product = product_with_prices("Single Price Gadget", [ 49.99 ])

    with_ai_disabled do
      answer = AiAssistant.call(query: "best gadget deal", products: [ product ])
      pick = answer.picks.find { |p| p.product == product }

      assert pick, "expected the single-price product to be picked"
      assert_no_match(/lowest you've ever seen|lowest ever|record low/i, pick.reason)
      assert_match(/only one price logged/i, pick.reason)
    end
  end

  test "still flags a real history low when latest matches the lowest of several prices" do
    product = product_with_prices("Falling Price TV", [ 120.00, 100.00, 80.00 ])

    with_ai_disabled do
      answer = AiAssistant.call(query: "falling tv", products: [ product ])
      pick = answer.picks.find { |p| p.product == product }

      assert pick
      assert_match(/lowest you've ever seen/i, pick.reason)
    end
  end

  test "heuristic source is used when AI is disabled" do
    product = product_with_prices("Anything", [ 20.00, 18.00 ])

    with_ai_disabled do
      answer = AiAssistant.call(query: "cheap", products: [ product ])
      assert_equal "local", answer.source
    end
  end
end
