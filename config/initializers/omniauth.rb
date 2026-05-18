Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    provider :google_oauth2,
             ENV.fetch("GOOGLE_CLIENT_ID"),
             ENV.fetch("GOOGLE_CLIENT_SECRET"),
             scope: "email,profile",
             prompt: "select_account"
  end
end

OmniAuth.config.allowed_request_methods = %i[ post ]
