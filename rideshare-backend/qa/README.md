# Manual QA harness

End-to-end feature checks that drive the **running** backend over HTTP the way
the apps do, rather than mocking it. They complement `npm test` (unit/contract),
which never touches a real database.

These scripts are dev tooling: they are not part of the build and Jest does not
pick them up.

## Prerequisites

1. PostgreSQL 16 + PostGIS on `localhost:5433` and Redis on `localhost:6379`
   (`scripts/local/start-services.ps1` from the repo root).
2. Migrations applied: `npm run db:migration:run`.
3. The API running on `localhost:3003`: `npm run start:dev`.
4. `OTP_PROVIDER=local` in `.env` — the suites read OTP codes straight out of
   the `otp_codes` table, so no SMS is sent.

## Running

Run them in order; `01` writes `qa/accounts.json`, which the rest read, and `03`
writes `qa/trip-context.json` for `05` and `06`.

```bash
node qa/01-accounts.js          # one account per role, admin approval
node qa/02-profile-vehicles-misc.js
node qa/03-trips-bookings.js    # ~2 min: waits for the trip auto-start job
node qa/04-instant-rides.js
node qa/05-wallet-payments-support.js
node qa/06-admin.js
```

Each script prints PASS/FAIL per check and exits non-zero on any failure.

## Notes

- `03` publishes a trip departing 75 seconds out so the delayed BullMQ
  `trip-auto-start` job fires inside the run; the completion section polls for
  the PUBLISHED → IN_PROGRESS transition rather than forcing the status.
- The suites are re-runnable. `02` rotates passenger 2's password, so it probes
  both known values; `04` cancels any live instant request first, since a
  passenger may only hold one.
- Accounts are created with fresh phone numbers per `01` run, so repeated runs
  accumulate test users rather than colliding.
