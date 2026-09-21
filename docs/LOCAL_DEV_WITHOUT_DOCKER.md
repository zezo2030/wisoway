# Local development without Docker (Windows)

Docker stays in the repo for deployment (`docker-compose.yml`). For day-to-day
development the backend and dashboard run natively, against a native
PostgreSQL + PostGIS and Redis installed on this machine.

## What is installed on the machine

| Service | Location | Port | Credentials |
|---|---|---|---|
| PostgreSQL 16.15 + PostGIS 3.6.2 | `C:\PostgreSQL\16` (data in `C:\PostgreSQL\16\data`) | 5433 | `postgres` / `203050` (same as `rideshare-backend/.env`) |
| Redis 8.10 (msys2 build) | `C:\Redis` (config `C:\Redis\redis.local.conf`, data in `C:\Redis\data`) | 6379 | none |

Neither runs as a Windows service (the install was done without admin rights).

## Start / stop the services

```powershell
powershell -ExecutionPolicy Bypass -File scripts\local\start-services.ps1   # idempotent
powershell -ExecutionPolicy Bypass -File scripts\local\status-services.ps1
powershell -ExecutionPolicy Bypass -File scripts\local\stop-services.ps1
```

To have them start at logon, put a shortcut to `start-services.ps1` in
`shell:startup` (Win+R -> `shell:startup`).

## Run the apps

```powershell
# backend  -> http://localhost:3003/api/v1  (health: /api/v1/health)
cd rideshare-backend
npm run db:migration:run     # only when there are new migrations
npm run start:dev

# dashboard -> http://localhost:5173
cd rideshare-dashboard
npm run dev
```

Default admin (auto-seeded on first backend boot): `admin@rideshare.com` / `Admin@123456`.

## Env files

- `rideshare-backend/.env` — `POSTGRES_HOST=localhost`, `POSTGRES_PORT=5433`,
  `REDIS_HOST=localhost`, `OTP_PROVIDER=local` (OTP codes are printed in the
  backend log, no SMS is sent). `JWT_SECRET` mirrors `JWT_ACCESS_SECRET`.
- `rideshare-dashboard/.env` — `VITE_API_BASE_URL=http://localhost:3003/api/v1`,
  `VITE_WS_URL=http://localhost:3003`. Firebase web-push keys are optional; the
  dashboard skips push registration when they are empty.
- Root `.env` is only read by `docker compose`.

## Notes

- The EDB PostgreSQL installer (get.enterprisedb.com) is geo-blocked from this
  network. The binaries under `C:\PostgreSQL\16` are the same EDB build
  redistributed via Maven Central (`io.zonky.test.postgres`), plus the OSGeo
  PostGIS bundle copied over it. There is no `psql.exe`; use a GUI client or the
  backend's `pg` driver.
- The database was created fresh. Data that lived in the old Docker volume
  `postgres_data` was not migrated (Docker Desktop is not running).
