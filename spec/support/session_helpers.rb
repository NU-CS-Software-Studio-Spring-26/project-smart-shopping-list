module SessionHelpers
  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "Secure!99" }
  end
end

RSpec.configure do |config|
  config.include SessionHelpers, type: :request
end
