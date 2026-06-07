require "rails_helper"

RSpec.describe "Registration", type: :request do
  describe "POST /registration" do
    it "creates an account when terms are accepted" do
      expect {
        post registration_path, params: {
          user: {
            email_address: "rspec-register@example.com",
            password: "Secure!99",
            password_confirmation: "Secure!99",
            terms_accepted: "1"
          }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
    end

    it "rejects sign-up when terms are not accepted" do
      post registration_path, params: {
        user: {
          email_address: "rspec-noterms@example.com",
          password: "Secure!99",
          password_confirmation: "Secure!99",
          terms_accepted: "0"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/terms/i)
    end
  end
end
