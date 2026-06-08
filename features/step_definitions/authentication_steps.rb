Given("I am signed in as {string}") do |email|
  password = "Cuke!Pass#42xq"
  User.find_or_create_by!(email_address: email) do |u|
    u.password = password
    u.password_confirmation = password
    u.terms_accepted = "1"
  end
  post session_path, params: { email_address: email, password: password }
  follow_redirect! while response.redirect?
end

Given("I am on the sign-up page") do
  get new_registration_path
  assert_response :ok
end

When("I visit the products page while signed out") do
  get products_path
end

Then("I should be redirected to sign in") do
  assert_redirected_to new_session_path
end

Then("I should be signed in") do
  get root_path
  follow_redirect! while response.redirect?
  raise "Expected signed-in UI" unless response.body.to_s.match?(/Sign out/i)
end
