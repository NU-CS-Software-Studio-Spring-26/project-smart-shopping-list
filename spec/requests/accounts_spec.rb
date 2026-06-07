require "rails_helper"

RSpec.describe "Account settings", type: :request do
  def create_user!
    User.create!(
      email_address: "account-#{SecureRandom.hex(4)}@example.com",
      password: "Secure!99",
      password_confirmation: "Secure!99",
      terms_accepted: true
    )
  end

  describe "GET /account" do
    it "renders the settings page" do
      user = create_user!
      sign_in_as(user)

      get account_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Settings")
    end
  end

  describe "PATCH /account password" do
    it "updates the password when the current password is correct" do
      user = create_user!
      sign_in_as(user)

      patch account_path, params: {
        current_password: "Secure!99",
        password: "NewSecure!1",
        password_confirmation: "NewSecure!1"
      }

      expect(response).to redirect_to(account_path)
      expect(user.reload.authenticate("NewSecure!1")).to be_truthy
    end

    it "rejects an incorrect current password" do
      user = create_user!
      sign_in_as(user)

      patch account_path, params: {
        current_password: "wrong",
        password: "NewSecure!1",
        password_confirmation: "NewSecure!1"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("incorrect")
    end
  end

  describe "DELETE /account" do
    it "deletes the account when the password is confirmed" do
      user = create_user!
      sign_in_as(user)

      expect {
        delete account_path, params: { password_confirmation: "Secure!99" }
      }.to change(User, :count).by(-1)

      expect(response).to redirect_to(root_path)
    end
  end
end
