When("I register with a new account and password {string}") do |password|
  email = "cucumber-#{SecureRandom.hex(4)}@example.com"
  post registration_path, params: {
    user: {
      email_address: email,
      password: password,
      password_confirmation: password,
      terms_accepted: "1"
    }
  }
  follow_redirect! if response.redirect?
end

When("I register with email {string} and password {string}") do |email, password|
  post registration_path, params: {
    user: {
      email_address: email,
      password: password,
      password_confirmation: password,
      terms_accepted: "1"
    }
  }
  follow_redirect! if response.redirect?
end

When("I try to register without accepting terms") do
  post registration_path, params: {
    user: {
      email_address: "noterms-#{SecureRandom.hex(4)}@example.com",
      password: "Secure!99",
      password_confirmation: "Secure!99",
      terms_accepted: "0"
    }
  }
end

Then("I should see {string}") do |text|
  raise "Expected to see #{text.inspect}" unless response.body.to_s.include?(text)
end

Then("I should see a terms acceptance error") do
  raise "Expected 422, got #{response.status}" unless response.status == 422
  raise "Expected terms error in body" unless response.body.to_s.match?(/terms/i)
end
