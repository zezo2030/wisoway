# API Contracts: Platform Refinements

All endpoints below are **additive** (constitution I). They live under the existing `/api/v1` base. Auth is the existing JWT bearer scheme; role gates are noted per endpoint. Every endpoint requires a contract test written red-green before implementation (constitution II).

| Contract | Endpoints | Consumer |
|----------|-----------|----------|
| [locations-autocomplete.md](./locations-autocomplete.md) | `GET /locations/autocomplete`, `GET /locations/place/:id` | Mobile (trip create & search) |
| [vehicle-types.md](./vehicle-types.md) | `GET /vehicles/types` | Mobile (vehicle setup / create trip) |
| [admin-web-push.md](./admin-web-push.md) | `POST /notifications/web-token`, `DELETE /notifications/web-token`, `GET/PATCH /admin/alert-preferences` | Dashboard |

Unchanged but referenced:
- `GET /users/me` — already returns `isDriverApproved`; the mobile approval-freshness fix re-calls it on create-flow entry + foreground (no contract change).
- `POST /trips` — already validates `driver.isDriverApproved`; unchanged.
- `PATCH /admin/users/:id/approve-driver` — existing approval action; triggers the driver-registration/approval flow (no contract change).
