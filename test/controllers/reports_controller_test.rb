require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get reports" do
    products(:one).update!(tags_input: "school, gifts", target_price: 15)
    products(:one).price_records.create!(price: 12, store_name: "Target", recorded_at: Time.current)

    get reports_url

    assert_response :success
    assert_match "Watchlist performance", response.body
    assert_match "Products by category", response.body
    assert_match "Products by tag", response.body
    assert_match "Download watchlist CSV", response.body
  end

  test "should redirect unauthenticated user to sign in" do
    sign_out
    get reports_url
    assert_redirected_to new_session_url
  end
end
