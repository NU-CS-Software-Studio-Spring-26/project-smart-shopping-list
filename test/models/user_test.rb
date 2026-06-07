require "test_helper"

class UserTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      email_address: "person@example.com",
      password: "Test#Pass9!",
      password_confirmation: "Test#Pass9!",
      terms_accepted: true
    }.merge(overrides)
  end

  test "terms_accepted is required on create for password users" do
    user = User.new(valid_attributes(terms_accepted: false))
    assert_not user.valid?
    assert_includes user.errors[:terms_accepted], "must be accepted before creating an account"
  end

  test "avatar rejects non-image content types" do
    user = users(:one)
    user.avatar.attach(
      io: StringIO.new("plain text"),
      filename: "notes.txt",
      content_type: "text/plain"
    )
    assert_not user.valid?
    assert_includes user.errors[:avatar], "must be a PNG, JPEG, WebP, or GIF image"
  end

  test "valid with email + password" do
    assert User.new(valid_attributes).valid?
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email_address
  end

  # The live checklist mirrors these server-side rules (#70). Keep them in sync.
  test "PASSWORD_REQUIREMENTS exposes the client-checkable rule keys" do
    assert_equal %w[length special no_repeats], User::PASSWORD_REQUIREMENTS.map { |r| r[:key] }
  end

  test "password shorter than the minimum length is rejected" do
    user = User.new(valid_attributes(password: "Ab#1", password_confirmation: "Ab#1"))
    assert_not user.valid?
    assert(user.errors[:password].any? { |m| m.include?("at least") })
  end

  test "password without a special character is rejected" do
    user = User.new(valid_attributes(password: "Abcdefg9", password_confirmation: "Abcdefg9"))
    assert_not user.valid?
    assert(user.errors[:password].any? { |m| m.include?("special character") })
  end

  test "password with three repeated characters in a row is rejected" do
    user = User.new(valid_attributes(password: "Abbb#cd9", password_confirmation: "Abbb#cd9"))
    assert_not user.valid?
    assert(user.errors[:password].any? { |m| m.include?("repeated") })
  end

  test "invalid without email_address" do
    user = User.new(valid_attributes(email_address: ""))
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "invalid with malformed email_address" do
    user = User.new(valid_attributes(email_address: "not-an-email"))
    assert_not user.valid?
    assert_includes user.errors[:email_address].join, "valid email"
  end

  test "rejects duplicate email_address (case-insensitive)" do
    User.create!(valid_attributes(email_address: "dup@example.com"))
    dup = User.new(valid_attributes(email_address: "DUP@example.com"))
    assert_not dup.valid?
    assert_includes dup.errors[:email_address], "has already been taken"
  end

  test "invalid without password" do
    user = User.new(valid_attributes.merge(password: "", password_confirmation: ""))
    assert_not user.valid?
  end

  test "from_omniauth creates a user with generated password" do
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-123",
      info: {
        email: "oauth@example.com",
        name: "OAuth User",
        image: "https://example.com/avatar.png"
      }
    )

    assert_difference("User.count") do
      user = User.from_omniauth(auth)

      assert_equal "oauth@example.com", user.email_address
      assert_equal "google_oauth2", user.provider
      assert_equal "google-123", user.uid
      assert user.authenticate(user.password)
    end
  end

  test "from_omniauth links an existing user by email" do
    user = User.create!(valid_attributes(email_address: "linkme@example.com"))
    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-456",
      info: { email: "linkme@example.com", name: "Linked User" }
    )

    assert_no_difference("User.count") do
      linked = User.from_omniauth(auth)

      assert_equal user.id, linked.id
      assert_equal "google_oauth2", linked.provider
      assert_equal "google-456", linked.uid
      assert linked.authenticate("Test#Pass9!")
    end
  end

  test "from_omniauth links existing user when stored email casing differs" do
    user = User.create!(valid_attributes(email_address: "legacy@example.com"))
    user.update_column(:email_address, "Legacy@Example.com")

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-legacy",
      info: { email: "legacy@example.com", name: "Legacy User" }
    )

    assert_no_difference("User.count") do
      linked = User.from_omniauth(auth)
      assert_equal user.id, linked.id
      assert_equal "legacy@example.com", linked.email_address
    end
  end

  test "merge_accounts! combines products and prefers the password account when tied" do
    password_user = User.create!(valid_attributes(email_address: "merge-password@example.com"))
    password_user.products.create!(name: "Password product", category: "Books")

    oauth_user = User.create!(
      email_address: "merge-oauth@example.com",
      password: "Oauth#Pass9!",
      password_confirmation: "Oauth#Pass9!",
      provider: "google_oauth2",
      uid: "google-merge"
    )
    oauth_user.products.create!(name: "OAuth product", category: "Books")

    assert_difference("User.count", -1) do
      merged = User.merge_accounts!([ password_user, oauth_user ])

      assert_equal password_user.id, merged.id
      assert_equal 2, merged.products.count
      assert_includes merged.products.pluck(:name), "OAuth product"
      assert_includes merged.products.pluck(:name), "Password product"
      assert_nil User.find_by(id: oauth_user.id)
    end
  end

  test "from_omniauth merges related accounts that share an email" do
    password_user = User.create!(valid_attributes(email_address: "merge-password@example.com"))
    password_user.products.create!(name: "Password product", category: "Books")

    oauth_user = User.create!(
      email_address: "merge-oauth@example.com",
      password: "Oauth#Pass9!",
      password_confirmation: "Oauth#Pass9!",
      provider: "google_oauth2",
      uid: "google-merge-link"
    )
    oauth_user.products.create!(name: "OAuth product", category: "Books")

    auth = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-merge-link",
      info: { email: "shared@example.com", name: "Merged User" }
    )

    assert_difference("User.count", -1) do
      stub_method(User, :accounts_for_email, ->(_email) { [ password_user, oauth_user ] }) do
        merged = User.from_omniauth(auth)

        assert_equal password_user.id, merged.id
        assert_equal "google_oauth2", merged.provider
        assert_equal "google-merge-link", merged.uid
        assert_equal 2, merged.products.count
        assert_nil User.find_by(id: oauth_user.id)
      end
    end
  end

  test "from_omniauth rejects missing email" do
    auth = OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "no-email", info: {})

    error = assert_raises(User::OauthError) { User.from_omniauth(auth) }
    assert_match(/email/i, error.message)
  end
end
