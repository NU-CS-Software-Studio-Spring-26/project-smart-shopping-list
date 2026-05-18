# Sign in with Google via OmniAuth.
#
# Credentials come from ENV:
# GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET.
Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    provider :google_oauth2,
             ENV.fetch("GOOGLE_CLIENT_ID"),
             ENV.fetch("GOOGLE_CLIENT_SECRET"),
             scope: "email,profile",
             prompt: "select_account",
             access_type: "online"
  end
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

OmniAuth.config.on_failure = lambda do |env|
  message = env["omniauth.error"]&.message || env["omniauth.error.type"] || "unknown error"
  Rails.logger.warn("[OmniAuth] failure: #{message}")

  new_session_url = Rails.application.routes.url_helpers.new_session_path
  [ 302, { "Location" => "#{new_session_url}?oauth_error=1", "Content-Type" => "text/html" }, [] ]
end
