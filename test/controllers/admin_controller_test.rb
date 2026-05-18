require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  # Shared "good" token used by every happy-path test.
  GOOD_TOKEN = "test-admin-secret-do-not-use-in-prod".freeze

  setup do
    @original_token = ENV["ADMIN_REFRESH_TOKEN"]
    ENV["ADMIN_REFRESH_TOKEN"] = GOOD_TOKEN
  end

  teardown do
    if @original_token.nil?
      ENV.delete("ADMIN_REFRESH_TOKEN")
    else
      ENV["ADMIN_REFRESH_TOKEN"] = @original_token
    end
  end

  # ---------- authentication ----------

  test "POST /admin/refresh_prices without any token is 401" do
    no_op_refresh do
      post "/admin/refresh_prices"
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices with a wrong token is 401" do
    no_op_refresh do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => "totally-wrong" }
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices with a blank token is 401" do
    no_op_refresh do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => "" }
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices is 401 when ADMIN_REFRESH_TOKEN is unset (fail-closed)" do
    ENV.delete("ADMIN_REFRESH_TOKEN")
    no_op_refresh do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => GOOD_TOKEN }
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices does not require a logged-in session" do
    # No sign_in_as call. This proves allow_unauthenticated_access works:
    # if the cookie-based before_action :require_authentication were still
    # active, the response would be a 302 redirect to /sessions/new instead
    # of the 200 we expect with a valid token.
    no_op_refresh do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => GOOD_TOKEN }
    end
    assert_response :ok
  end

  # ---------- happy path ----------

  test "POST /admin/refresh_prices with the right token calls PriceFetcher.refresh_all and returns its summary" do
    called = false
    fake_summary = { succeeded: 3, failed: 1, duration: 4.2 }
    stub_method(PriceFetcher, :refresh_all, -> {
      called = true
      fake_summary
    }) do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => GOOD_TOKEN }
    end

    assert called, "AdminController#refresh_prices should have invoked PriceFetcher.refresh_all"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
    assert_equal 3,    body["succeeded"]
    assert_equal 1,    body["failed"]
    assert_in_delta 4.2, body["duration"], 0.001
  end

  # Helper: stub PriceFetcher.refresh_all so 401-checking tests never touch
  # the real scraper code path. Even when we expect a 401 we may still go
  # through router/CSRF/before_actions, so it's safer to stub uniformly.
  def no_op_refresh(&block)
    stub_method(PriceFetcher, :refresh_all, -> { { succeeded: 0, failed: 0, duration: 0.0 } }, &block)
  end
end
