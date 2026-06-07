require "rails_helper"

RSpec.describe "Authentication guards", type: :request do
  it "redirects guests away from the products dashboard" do
    get products_path
    expect(response).to redirect_to(new_session_path)
  end
end
