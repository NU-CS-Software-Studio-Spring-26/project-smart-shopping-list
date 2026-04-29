# Changelog

All notable changes to **PriceTracker (Smart Shopping List)** are documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.0] — 2026-04-29 — Milestone 1 (MVP)

First public release. The application is deployed on Heroku at
<https://smart-shoppinglist-6ae31171e85c.herokuapp.com/> and supports a complete
end-to-end "happy path" for tracking product prices.

Tag: [`v1.0.0`](https://github.com/NU-CS-Software-Studio-Spring-26/project-smart-shopping-list/releases/tag/v1.0.0)

### Added
- User accounts with email + password (`has_secure_password`), session-cookie auth,
  signup / sign-in / sign-out flows, and password reset.
- Products CRUD scoped to the current user — no user can read or mutate another
  user's products or price records.
- Manual price entry: per-product price history table with store, date, notes,
  and optional store URL.
- Automatic price scraping from a product page URL:
  - Adapter pattern with a registry (`app/services/price_scrapers/`).
  - Generic `JsonLdAdapter` that supports any site exposing `schema.org` Product
    JSON-LD (Target, Walmart, Best Buy, Lululemon, Nike, etc.).
  - Site-specific `AmazonAdapter` for Amazon's CSS-driven layout.
  - First scrape happens synchronously on product creation; users only need to
    paste a URL + pick a category, and the title / image / first price are
    fetched automatically.
  - Manual "Fetch latest price" button on each product detail page.
  - Price deduping: a new `PriceRecord` is only created when the scraped price
    actually differs from the last scraped price for that product.
  - Heroku Scheduler-friendly `PriceFetcher.refresh_stale` task for off-process
    refreshes (no extra worker dyno required).
- Products list page: case-insensitive multi-token search across name,
  category, and description.
- Bootstrap-based responsive UI with consistent global header, footer, primary
  CTA, and flash styling. Empty states for products list and price history.
- Database schema documentation in `docs/database.md` and full scraper
  architecture reference in `docs/scrapers.md`.
- CI on every push and PR: RuboCop lint, Brakeman static analysis,
  bundler-audit, importmap audit, and the full Minitest suite against PostgreSQL.

### Security
- Secrets (Rails master key, third-party API keys) are stored in environment
  variables / encrypted credentials only — never committed to the repository.
- Authentication is rate-limited (10 attempts / 3 minutes) and CSRF-protected.
- Failed login responses are intentionally generic so they cannot be used to
  enumerate which email addresses exist.
