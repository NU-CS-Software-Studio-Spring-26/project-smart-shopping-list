require "rails_helper"

RSpec.describe "Rate limiting (Rack::Attack)", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  it "throttles excessive login attempts from the same IP" do
    11.times do
      post session_path, params: { email_address: "nobody@example.com", password: "wrong" }
    end
    expect(response).to have_http_status(:too_many_requests)
  end

  it "throttles excessive signup attempts from the same IP" do
    6.times do |i|
      post registration_path, params: {
        user: { email_address: "spam#{i}@example.com", password: "x", password_confirmation: "x" }
      }
    end
    expect(response).to have_http_status(:too_many_requests)
  end

  it "allows normal traffic to pass through" do
    get new_session_path
    expect(response).to have_http_status(:ok)
  end
end
