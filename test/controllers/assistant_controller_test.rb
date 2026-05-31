require "test_helper"

class AssistantControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "ask page renders the ask_ai_results turbo frame" do
    get assistant_url
    assert_response :success
    assert_select "turbo-frame#ask_ai_results"
  end

  test "ask page does NOT render the floating widget (avoids duplicate frame id)" do
    get assistant_url
    assert_select ".pt-askai-fab", count: 0
  end

  test "other pages render the global Ask AI widget with its own frame" do
    get products_url
    assert_response :success
    assert_select ".pt-askai-fab"
    assert_select "turbo-frame#ask_ai_results"
  end

  test "submitting a question renders an answer inside the frame" do
    products(:one).update!(name: "Wireless Headphones")
    products(:one).price_records.create!(price: 99, store_name: "Target", recorded_at: Time.current)

    get assistant_url(q: "headphones")
    assert_response :success
    assert_select "turbo-frame#ask_ai_results" do
      assert_match(/Suggestions for/, response.body)
    end
  end
end
