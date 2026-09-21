# Implementation Plan: Platform Refinements (Localization, Admin Alerts & Trip-Creation UX)

**Branch**: `009-platform-refinements` | **Date**: 2026-06-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/009-platform-refinements/spec.md`

## Summary

Five independent refinements across the three surfaces of the platform:

1. **Approved-driver trip creation without restart** — the mobile app caches `isDriverApproved` once at startup and never refreshes it, so a freshly-approved driver is blocked until they kill and relaunch the app. Fix: re-fetch the driver's profile when the create-trip flow is opened and when the app returns to the foreground (per clarification).
2. **Live origin/destination suggestions** — the location fields only support tap-on-map + reverse geocoding today. Add place autocomplete, fed by a backend proxy over Google Places (key kept server-side), returning language- and region-aware suggestions plus a place-detail lookup for coordinates.
3. **Automatic seat layout from vehicle type** — introduce a canonical vehicle-type → seat-layout-template catalog on the backend, exposed read-only to clients; selecting a vehicle type auto-applies its template (still editable for irregular layouts), and trip creation continues to resolve seats from the stored layout.
4. **Admin web-push alerts** — add Firebase Cloud Messaging **for Web** to the dashboard (service worker + token registration), reusing the backend's existing Firebase Admin SDK to push driver-registration and in-app-fee-payment alerts to subscribed admin/operator users, deep-linking to `/users/:id` and `/payments`.
5. **AR/EN translation correctness sweep** — verify completeness and correctness across the mobile app and the dashboard, and add a CI-checkable key-parity guard so future strings cannot ship untranslated.

The work is additive at the contract level (new endpoints, new nullable columns/config) and pairs each backend change with its client change in this branch, per the constitution.

## Technical Context

**Language/Version**: TypeScript 5.7 (backend, NestJS 11); Dart 3.x / Flutter 3.9.2 (mobile); TypeScript 5.9 + React 19 + Vite 7 (dashboard)
**Primary Dependencies**:
- Backend: NestJS, TypeORM, BullMQ, Firebase Admin SDK (FCM — already integrated), Socket.IO, `@googlemaps/google-maps-services-js` *(new, server-side Places proxy)*, `firebase-admin.messaging()` for web push *(reuse)*
- Mobile: `provider`, `dio`, `google_maps_flutter`, `geolocator`, `geocoding`, `flutter_localizations` (gen-l10n); place autocomplete consumed via backend (no new Google key on device)
- Dashboard: `react-router-dom`, `@tanstack/react-query`, `socket.io-client`, custom i18n in `src/i18n/translations.ts`; `firebase` JS SDK *(new, FCM web)* + a `firebase-messaging-sw.js` service worker *(new)*
**Storage**: PostgreSQL (PostGIS on trips) via TypeORM; Redis (BullMQ + cache). New: `web_push_token` (or extend `device_tokens` with a `platform=web` row) for dashboard FCM web tokens; admin alert subscription preferences; vehicle-type catalog (static config module, optionally a seed table).
**Testing**: Backend `npm test` (Jest unit + `test/contract`, `test/integration`, e2e); mobile `flutter test` + `flutter analyze`; dashboard `tsc -b` + build. New contract tests for every new endpoint (constitution II).
**Target Platform**: iOS/Android (mobile app), evergreen browsers desktop+mobile (dashboard), Linux server (backend)
**Project Type**: Multi-surface (mobile + web dashboard + backend API) — three existing top-level projects.
**Performance Goals**: Suggestions visible <~1s after typing (SC-003); admin alerts delivered <~1 min (SC-005); approval reflected on next create-flow entry/foreground (SC-001).
**Constraints**: Google API key MUST stay server-side (constitution IV); new endpoints additive/versioned-safe (constitution I); backend↔client changes paired in this branch (constitution V); place-autocomplete must degrade gracefully offline (FR-008).
**Scale/Scope**: Existing user base; 5 features touching ~3 backend modules (locations, vehicles, notifications/admin), ~4 mobile areas, ~3 dashboard areas, plus an i18n parity check per client.

**Note on spec assumption correction**: The spec referenced the dashboard using `react-i18next`; the actual implementation is a custom `LanguageProvider` + `src/i18n/translations.ts` with full RTL handling. The localization sweep and parity guard target that actual setup. No behavior in the spec changes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment | Status |
|-----------|-----------|--------|
| **I. API Contract Stability** | All new endpoints (`/locations/autocomplete`, `/locations/place/:id`, `/vehicles/types`, web-push token register, admin alert prefs) are additive; the in-app-fee-payment alert hooks an existing event. No removed/renamed fields. | ✅ Pass |
| **II. Test-First (NON-NEGOTIABLE)** | Plan mandates contract tests for each new endpoint and unit tests for the alert trigger, seat-template resolver, and profile-refresh logic, written red-green before implementation. | ✅ Pass (enforced in tasks) |
| **III. Observability & Auditability** | Admin-alert sends emit structured logs (event type, recipient count, outcome). Payment-triggered alerts reference the existing audited payment record; no new money movement is introduced. | ✅ Pass |
| **IV. Security & PII Protection** | Google Places key stays server-side via the proxy; autocomplete queries are not written to general logs; web-push token endpoints are auth-gated; admin alert delivery is admin/operator-role only and authorized server-side. | ✅ Pass |
| **V. Cross-Platform Parity** | Each backend change ships with its client change in this branch: autocomplete proxy ↔ mobile fields; vehicle-type catalog ↔ mobile prefill; web-push sender ↔ dashboard SW/registration. | ✅ Pass |

**Security & workflow specifics**: migrations are additive-safe (new nullable columns / new tables only); no destructive changes. No new secrets are committed (Google key and FCM VAPID/web config via env). Result: **no violations**, Complexity Tracking not required.

## Project Structure

### Documentation (this feature)

```text
specs/009-platform-refinements/
├── plan.md              # This file
├── research.md          # Phase 0 output — tech decisions
├── data-model.md        # Phase 1 output — entities & schema changes
├── quickstart.md        # Phase 1 output — how to run/verify
├── contracts/           # Phase 1 output — endpoint contracts
│   ├── locations-autocomplete.md
│   ├── vehicle-types.md
│   ├── admin-web-push.md
│   └── README.md
├── checklists/
│   └── requirements.md  # from /speckit.specify
└── tasks.md             # /speckit.tasks output (NOT created here)
```

### Source Code (repository root)

```text
rideshare-backend/                      # NestJS API
└── src/
    ├── modules/
    │   ├── locations/                  # ADD: places autocomplete proxy + place details
    │   │   ├── locations.controller.ts # ADD GET /locations/autocomplete, /locations/place/:id
    │   │   ├── locations.service.ts    # ADD Google Places client + session-token + cache
    │   │   └── dto/
    │   ├── vehicles/                   # ADD: vehicle-type → seat-layout catalog
    │   │   ├── vehicle-types.ts        # ADD canonical catalog (type → SeatLayout template)
    │   │   └── vehicles.controller.ts  # ADD GET /vehicles/types
    │   ├── notifications/              # ADD: web-push (FCM web) send path + token kind
    │   │   ├── notifications.service.ts# EXTEND sendPush to target web tokens
    │   │   └── web-push.service.ts     # ADD (or fold into notifications.service)
    │   └── admin/                      # ADD: alert triggers + subscription prefs
    │       ├── admin-alerts.service.ts # ADD fire-on-driver-registration / fee-payment
    │       └── admin.controller.ts     # ADD alert-subscription prefs endpoints
    ├── database/
    │   ├── entities/                   # device-token kind=web; admin-alert-preference
    │   └── migrations/                 # additive migrations
    └── test/                           # contract + integration tests (new)

rideshare/                              # Flutter mobile app
└── lib/
    ├── providers/auth_provider.dart    # FIX: refresh profile on resume + create-flow entry
    ├── main.dart                       # ADD: WidgetsBindingObserver → refresh on resumed
    ├── screens/driver/
    │   ├── create_trip_screen.dart     # refresh gate; wire autocomplete fields
    │   └── vehicle_settings_screen.dart# auto-apply seat template on vehicle-type change
    ├── widgets/
    │   ├── location_autocomplete_field.dart  # ADD: live-suggestion text field
    │   └── location_picker_widget.dart # keep map fallback
    ├── core/services/location_service.dart   # ADD autocomplete/place-detail calls
    ├── core/api/api_endpoints.dart     # ADD new endpoints
    └── l10n/                           # fill AR/EN gaps; parity check

rideshare-dashboard/                    # React + Vite admin dashboard
├── public/
│   └── firebase-messaging-sw.js        # ADD: FCM web service worker
└── src/
    ├── lib/firebase.ts                 # ADD: FCM web init + token + onMessage
    ├── providers/notifications-socket-provider.tsx # integrate web-push opt-in
    ├── api/admin.ts                    # ADD register web-push token, alert prefs
    ├── i18n/translations.ts            # fill AR/EN gaps; add alert keys
    └── scripts/check-i18n-parity.ts    # ADD: en/ar key-parity guard
```

**Structure Decision**: Retain the three existing top-level projects (`rideshare-backend`, `rideshare`, `rideshare-dashboard`). No new project is introduced; all work extends existing modules. This matches the constitution's three-surface model and keeps contracts shared-by-convention with explicit paired updates.

## Complexity Tracking

> No constitution violations — section intentionally empty.
