class Rack::Attack
  # Throttle auth endpoints to reduce brute-force attempts during development.
  throttle("auth/ip", limit: 10, period: 60) do |req|
    next unless req.post?

    auth_paths = [
      "/api/v1/auth/email/login",
      "/api/v1/auth/email/register",
      "/api/v1/auth/refresh"
    ]

    req.ip if auth_paths.include?(req.path)
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "rate_limited", message: "Too many requests. Please try again later." }.to_json]
    ]
  end
end
