class AdminController < ApplicationController
  # External cron (GitHub Actions) calls this with no session and no CSRF
  # token — it authenticates with a shared secret in the `X-Admin-Token`
  # header. Skip the cookie-based auth + CSRF protection accordingly.
  allow_unauthenticated_access only: :refresh_prices
  skip_forgery_protection only: :refresh_prices

  before_action :authenticate_admin_token!, only: :refresh_prices

  # POST /admin/refresh_prices
  #
  # Triggers PriceFetcher.refresh_all synchronously and returns a small JSON
  # summary the cron job can log. Synchronous is fine here because (a) the
  # set of products is small and (b) GitHub Actions has a generous job
  # timeout. If product count grows large, switch to refresh_stale or move
  # the work into ActiveJob.
  def refresh_prices
    summary = PriceFetcher.refresh_all
    render json: { ok: true }.merge(summary)
  end

  private

  # Compare the provided token against ADMIN_REFRESH_TOKEN using a constant-
  # time comparison so we don't leak token contents via timing. We require
  # the env var to be present; if it isn't configured, every request is
  # rejected (fail-closed default).
  def authenticate_admin_token!
    expected = ENV["ADMIN_REFRESH_TOKEN"].to_s
    provided = request.headers["X-Admin-Token"].to_s

    authorized =
      expected.present? &&
      provided.present? &&
      ActiveSupport::SecurityUtils.secure_compare(provided, expected)

    head :unauthorized unless authorized
  end
end
