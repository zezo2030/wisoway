# PostgreSQL + PostGIS Cutover Runbook

## 1) Prerequisites
- PostgreSQL 14+ with `postgis` extension installed.
- `.env` updated with `POSTGRES_*` values.
- MongoDB source data accessible via `MONGODB_URI`.

### Docker option (recommended for local dev)
- A ready compose file exists at `rideshare-backend/docker-compose.db.yml`.
- Start DB stack (Postgres + PostGIS + Mongo + Redis):
  - `docker compose -f docker-compose.db.yml --env-file .env up -d`
- Stop stack:
  - `docker compose -f docker-compose.db.yml --env-file .env down`

## 2) Prepare schema
1. Build backend:
   - `npm run build`
2. Run DB migration:
   - `npm run db:migration:run`

## 3) Backfill data from MongoDB
1. Execute backfill script:
   - `npm run db:backfill`
2. Validate migrated records in PostgreSQL:
   - row counts for `users`, `trips`, `wallet_accounts`.

## 4) Functional checks
- API checks:
  - `GET /api/v1/tracking/nearby/trips`
  - `GET /api/v1/wallet/me`
  - `GET /api/v1/tracking/:tripId/latest`
- Socket checks:
  - `/tracking`: `trip:tracking:subscribe`, `driver:location:update`
  - `/notifications`: `subscribe`, `newNotification`

## 5) Cutover window
1. Enable maintenance mode for write-heavy operations.
2. Run final incremental backfill.
3. Restart backend services.
4. Monitor logs/metrics for 15-30 minutes.

## 6) Rollback
- Keep MongoDB write path available during first release window.
- If critical issue:
  1. Disable new tracking/wallet routes.
  2. Revert deployment to previous backend release.
  3. Re-enable MongoDB-only path.
