require "test_helper"

# Locks in the four security guarantees we promised:
#   1. Protected pages aren't reachable without authentication.
#   2. Authenticated users can't read or mutate another user's records.
#   3. Login/logout produce flash messages.
#   4. Invalid login messages don't disclose whether an email exists.
class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @owner    = users(:one)
    @intruder = users(:two)
    @owners_product = products(:one)
  end

  # --- (1) auth required on protected pages ---

  test "anonymous request to products index redirects to sign in" do
    get products_path
    assert_redirected_to new_session_path
  end

  test "anonymous request to a product detail redirects to sign in" do
    get product_path(@owners_product)
    assert_redirected_to new_session_path
  end

  test "anonymous request to price records index redirects to sign in" do
    get price_records_path
    assert_redirected_to new_session_path
  end

  # --- (2) one user cannot touch another user's records ---

  test "intruder cannot show another user's product" do
    sign_in_as(@intruder)
    get product_path(@owners_product)
    assert_response :not_found
  end

  test "intruder cannot edit another user's product" do
    sign_in_as(@intruder)
    get edit_product_path(@owners_product)
    assert_response :not_found
  end

  test "intruder cannot update another user's product" do
    sign_in_as(@intruder)
    original_name = @owners_product.name
    patch product_path(@owners_product), params: { product: { name: "Hacked" } }
    assert_response :not_found
    assert_equal original_name, @owners_product.reload.name
  end

  test "intruder cannot destroy another user's product" do
    sign_in_as(@intruder)
    delete product_path(@owners_product)
    assert_response :not_found
    assert Product.exists?(@owners_product.id)
  end

  test "intruder cannot create a price record on another user's product" do
    sign_in_as(@intruder)
    post product_price_records_path(@owners_product),
         params: { price_record: { price: 1.0, store_name: "X", recorded_at: Time.current } }
    assert_response :not_found
  end

  # --- (3) flash on login / logout ---

  test "successful login sets a flash notice" do
    post session_path, params: { email_address: @owner.email_address, password: "password" }
    assert_redirected_to root_path
    assert_equal "Signed in.", flash[:notice]
  end

  test "logout sets a flash notice" do
    sign_in_as(@owner)
    delete session_path
    assert_redirected_to new_session_path
    assert_equal "Signed out.", flash[:notice]
  end

  # --- (4) invalid login does not disclose whether email exists ---

  test "wrong password and unknown email produce identical flash" do
    post session_path, params: { email_address: @owner.email_address, password: "wrong" }
    wrong_password_flash = flash[:alert]

    post session_path, params: { email_address: "nobody@nowhere.test", password: "anything" }
    unknown_email_flash = flash[:alert]

    assert_equal wrong_password_flash, unknown_email_flash
    assert_match(/email address or password/i, wrong_password_flash)
  end
end
