if Rails.env.test?
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  Rack::Attack.enabled = false
else
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

Rack::Attack.throttle("req/ip", limit: 300, period: 5.minutes) do |req|
  req.ip unless req.path.start_with?("/assets", "/packs", "/up")
end

Rack::Attack.throttle("logins/ip", limit: 10, period: 1.minute) do |req|
  req.ip if req.path == "/session" && req.post?
end

Rack::Attack.throttle("logins/email", limit: 10, period: 1.minute) do |req|
  if req.path == "/session" && req.post?
    req.params.dig("session", "email_address").to_s.downcase.presence ||
      req.params["email_address"].to_s.downcase.presence
  end
end

Rack::Attack.throttle("signups/ip", limit: 5, period: 1.hour) do |req|
  req.ip if req.path == "/registration" && req.post?
end

Rack::Attack.throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
  req.ip if req.path == "/passwords" && req.post?
end

Rack::Attack.throttled_responder = lambda do |request|
  retry_after = (request.env["rack.attack.match_data"] || {})[:period] || 60
  [
    429,
    { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
    [ "Too many requests. Please try again later.\n" ]
  ]
end
