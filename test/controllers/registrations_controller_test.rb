require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup requires terms acceptance" do
    assert_no_difference("User.count") do
      post registration_url, params: {
        user: {
          email_address: "noterms@example.com",
          password: "Secure!99",
          password_confirmation: "Secure!99",
          terms_accepted: "0"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_match(/terms/i, response.body)
  end

  test "signup succeeds when terms are accepted" do
    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: {
          email_address: "terms-ok@example.com",
          password: "Secure!99",
          password_confirmation: "Secure!99",
          terms_accepted: "1"
        }
      }
    end
    assert_redirected_to root_url
  end

  test "signup page renders the live password requirement checklist" do
    get new_registration_url
    assert_response :success
    assert_select "[data-controller='password-strength']"
    assert_select "[data-password-strength-target='password']"
    assert_select "[data-password-strength-target='confirmation']"
    # One checklist item per server-defined requirement.
    assert_select "[data-password-strength-target='rule']", count: User::PASSWORD_REQUIREMENTS.size
    User::PASSWORD_REQUIREMENTS.each do |req|
      assert_select "[data-rule=?]", req[:key]
    end
  end
end
