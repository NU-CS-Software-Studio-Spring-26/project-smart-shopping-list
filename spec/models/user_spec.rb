require "rails_helper"

RSpec.describe User, type: :model do
  describe "terms acceptance on sign-up" do
    it "requires terms to be accepted for password registration" do
      user = User.new(
        email_address: "rspec@example.com",
        password: "Secure!99",
        password_confirmation: "Secure!99",
        terms_accepted: false
      )

      expect(user).not_to be_valid
      expect(user.errors[:terms_accepted]).to include("must be accepted before creating an account")
    end

    it "allows sign-up when terms are accepted" do
      user = User.new(
        email_address: "rspec-ok@example.com",
        password: "Secure!99",
        password_confirmation: "Secure!99",
        terms_accepted: true
      )

      expect(user).to be_valid
    end
  end

  describe "avatar attachment" do
    let(:user) do
      User.create!(
        email_address: "avatar-spec@example.com",
        password: "Secure!99",
        password_confirmation: "Secure!99",
        terms_accepted: true
      )
    end

    it "rejects unsupported content types" do
      user.avatar.attach(
        io: StringIO.new("not an image"),
        filename: "notes.txt",
        content_type: "text/plain"
      )

      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to include("must be a PNG, JPEG, WebP, or GIF image")
    end
  end
end
