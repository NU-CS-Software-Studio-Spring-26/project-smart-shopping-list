# Sign in with Google via OmniAuth.
#
# Credentials come from ENV (set GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET locally
# and via `heroku config:set` in production). If they're missing — for example
# in CI or a fresh clone — we still register the strategy so routes resolve;
# the auth attempt itself will fail with a friendly OmniAuth failure rather
# than crashing boot.
#
# Test mode is enabled in test.rb so request specs can stub the callback via
# OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(...).
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_CLIENT_ID"],
           ENV["GOOGLE_CLIENT_SECRET"],
           scope: "email,profile",
           prompt: "select_account",
           access_type: "online"
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning     = true

OmniAuth.config.on_failure = lambda do |env|
  message = env["omniauth.error"]&.message || env["omniauth.error.type"] || "unknown error"
  Rails.logger.warn("[OmniAuth] failure: #{message}")

  new_session_url = Rails.application.routes.url_helpers.new_session_path
  [ 302, { "Location" => "#{new_session_url}?oauth_error=1", "Content-Type" => "text/html" }, [] ]
end
