require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders account settings" do
    get account_url
    assert_response :success
    assert_select "h1", /Settings/
  end

  test "update password with correct current password" do
    patch account_url, params: {
      current_password: "password",
      password: "NewSecure!1",
      password_confirmation: "NewSecure!1"
    }
    assert_redirected_to account_url
    assert @user.reload.authenticate("NewSecure!1")
  end

  test "destroy deletes account with password confirmation" do
    assert_difference("User.count", -1) do
      delete account_url, params: { password_confirmation: "password" }
    end
    assert_redirected_to root_url
  end

  test "guest cannot access account settings" do
    sign_out
    get account_url
    assert_redirected_to new_session_url
  end
end
