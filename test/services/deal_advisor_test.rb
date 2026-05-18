require "test_helper"

class DealAdvisorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @product = @user.products.create!(name: "Test Headphones", category: "Electronics", target_price: 90)
  end

  test "falls back gracefully when there is not enough history" do
    advice = with_ai_disabled { DealAdvisor.call(@product) }

    assert_equal "local", advice.source
    assert_match(/Log at least two prices/i, advice.summary)
  end

  test "recommends buying when latest price is below target" do
    @product.price_records.create!(price: 120, store_name: "Amazon", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 80, store_name: "Target", recorded_at: 1.day.ago)

    advice = with_ai_disabled { DealAdvisor.call(@product) }

    assert_equal "local", advice.source
    assert_match(/Buy now/i, advice.summary)
  end

  private

  def with_ai_disabled
    previous = ENV["ENABLE_AI_DEAL_ADVICE"]
    ENV["ENABLE_AI_DEAL_ADVICE"] = nil
    yield
  ensure
    ENV["ENABLE_AI_DEAL_ADVICE"] = previous
  end
end
