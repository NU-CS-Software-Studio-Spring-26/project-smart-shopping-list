require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "sets a default expiration on create" do
    session = users(:one).sessions.create!

    assert session.expires_at.future?
  end

  test "expired? reflects expires_at" do
    session = users(:one).sessions.build(expires_at: 1.minute.ago)

    assert session.expired?
  end
end
