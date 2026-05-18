# PriceTracker (Smart Shopping List)

## Team

Nicole Li, Andrew Xue, Amie Masih, Rahib Taher

## MVP

A web app where signed-in users save products they are watching, record prices seen at different stores, and review them from a simple dashboard. The baseline vision is to paste a product link, set a target price, and get notified when the price meets that condition (notifications are a stretch goal beyond the current milestone).

## Communication

- Weekly meetings on Saturday afternoons, with extra syncs when the app or deadlines need them.
- Decisions are coordinated through those meetings and ongoing chat; the team aims for consensus.
- If consensus is not reached in a reasonable time, decisions are resolved by majority vote.
- Decisions are documented with rationale. Small decisions can be async; blocking or complex issues are raised in meetings or escalated early.
- Choices prioritize simplicity and alignment with the MVP so progress stays steady.

## Links

- **OO design (Miro):** https://miro.com/app/board/uXjVGjU99U8=/
- **Scheduling (When2meet):** https://www.when2meet.com/?36156767-PyTqS
- **Heroku deployment:** https://smart-shoppinglist-6ae31171e85c.herokuapp.com/

## Automatic daily price refresh

Every product with a `source_url` is re-scraped once a day so the
price-history chart stays fresh without anyone clicking *Fetch latest
price* by hand.

- **Schedule** — `.github/workflows/refresh-prices.yml` runs at 09:00 UTC
  daily and can also be triggered manually from the *Actions* tab.
- **Trigger** — the workflow `POST`s to `/admin/refresh_prices` on the
  deployed app, authenticated by a shared secret (`X-Admin-Token` header,
  matched against `ENV["ADMIN_REFRESH_TOKEN"]` via constant-time compare).
- **Worker** — `AdminController#refresh_prices` calls
  `PriceFetcher.refresh_all`, which iterates every eligible product, calls
  the appropriate `PriceScrapers` adapter, and writes a new `PriceRecord`
  **only when the price has actually changed** (dedup). A per-product
  failure (timeout, 403 from Cloudflare/Akamai/PerimeterX-protected sites,
  unparseable HTML, …) is captured in `product.last_fetch_error` and never
  crashes the run.

We picked GitHub Actions cron over Solid Queue + a Heroku worker dyno
because it stays inside the GitHub Student `$13/month` credit, keeps the
schedule in version control, and is portable if we ever migrate off
Heroku — only `APP_URL` would change.

For setup steps, debugging, the full list of supported / unsupported
retailers, and the legal/ethical scraping notes, see:

- [`docs/scrapers.md`](docs/scrapers.md) — adapter contract, site support
  matrix, full request flow, troubleshooting.
- [`wiki.md` § Scheduled tasks](wiki.md) — one-time secret setup and
  manual-trigger verification.

## Ideas captured from early planning

- Save product links to the database with a user id.
- Save the date an item was added.
- Optionally save an image per item.
- After login, show a grid of saved items with cards; mark items as resolved.
- Set a “buy at” price and notify when price drops to that margin.
- Start by storing the price you saw manually (scraping across stores is uncertain).
