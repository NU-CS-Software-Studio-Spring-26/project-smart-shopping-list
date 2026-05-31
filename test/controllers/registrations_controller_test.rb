require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
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
