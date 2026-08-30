# Cloudflare production backend

The app includes a Cloudflare Workers API backed by a Cloudflare D1 database.

## Live API

`https://livraison-api.story-trends-dz.workers.dev`

## Demo accounts

Use the same value for email and password:

- `1 / 1` — client
- `2 / 2` — driver
- `3 / 3` — restaurant
- `4 / 4` — supplier
- `5 / 5` — admin

## Run Flutter against production

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://livraison-api.story-trends-dz.workers.dev
```

The app keeps the offline demo adapter when `API_BASE_URL` is omitted. Supabase remains an optional alternative through its existing compile-time defines.

## Redeploy the API

```bash
npx wrangler d1 execute livraison-prod --remote --file=cloudflare/worker/schema.sql
npx wrangler d1 execute livraison-prod --remote --file=cloudflare/worker/seed.sql
cd cloudflare/worker
npx wrangler deploy
```

The API provides role-based login, products, order lifecycle (`draft` → `confirmed` → `picked_up` → `delivered`), and an idempotent wallet ledger for restaurant, admin, and driver balances.
