# Quickstart: Platform Refinements

**Feature**: 009-platform-refinements | **Branch**: `009-platform-refinements`

How to configure, run, and verify each of the five refinements locally.

## Prerequisites

- Backend: Node + the existing `rideshare-backend` setup (PostgreSQL + PostGIS, Redis), `npm install`.
- Mobile: Flutter 3.9.2, `flutter pub get` in `rideshare`.
- Dashboard: Node, `npm install` in `rideshare-dashboard`.
- Existing Firebase project (already used for mobile FCM).

## New configuration / env

**Backend** (`.env`, never committed — constitution IV):
- `GOOGLE_PLACES_API_KEY` — server-side key for the autocomplete proxy (restrict to Places API).
- Firebase Admin SDK creds — already present (reused for web push).

**Dashboard** (`.env` → `VITE_*`):
- `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_MESSAGING_SENDER_ID`, `VITE_FIREBASE_APP_ID`
- `VITE_FIREBASE_VAPID_KEY` — FCM Web Push certificate public key (for `getToken({ vapidKey })`).
- The same values must be embedded in `public/firebase-messaging-sw.js`.

**Mobile**: no new key on device (autocomplete goes through the backend). `--dart-define=BASE_URL=...` as today.

## Run

```text
# backend
cd rideshare-backend && npm run db:migration:run && npm run start:dev
# dashboard
cd rideshare-dashboard && npm run dev
# mobile
cd rideshare && flutter run --dart-define=BASE_URL=http://<host>/api/v1
```

## Verify each story

### 1. Approved driver creates a trip without restart (P1)
1. Sign in on mobile as a pending driver; open create-trip → see "Account Under Review" gate.
2. In the dashboard (`/users/:id`), approve the driver. **Do not restart the mobile app.**
3. On mobile, background then foreground the app (or just reopen the create-trip flow) → gate clears, trip creation proceeds. ✅ SC-001.
4. Revoke approval in the dashboard, foreground again → gate re-blocks. ✅ FR-004.

### 2. Live origin/destination suggestions (P1)
1. In create-trip (and trip search), type ≥2 chars into "From"/"To" → ranked suggestions appear < ~1s, refining per keystroke. ✅ SC-003.
2. Tap a suggestion → field fills and coordinates are captured (visible on the map/summary). ✅ FR-006.
3. Switch app language → suggestions return in that language. Turn off network → field falls back to map picker, no crash. ✅ FR-007/FR-008.

### 3. Auto seat layout by vehicle type (P2)
1. In vehicle setup, pick each vehicle type → the seat layout auto-fills to that type's template. ✅ FR-009.
2. Change the type → layout replaces. ✅ FR-010. Save, create a trip → offered seats match the stored layout exactly. ✅ FR-011.
3. `GET /vehicles/types` returns every supported type with a non-empty layout. ✅ FR-012.

### 4. Admin web-push alerts (P2)
1. In the dashboard, accept the notification permission prompt → a web token registers (`POST /notifications/web-token`).
2. Register a new driver (mobile) → the admin's browser receives a web push within ~1 min; clicking it opens `/users/:id`. ✅ FR-013/SC-005.
3. Make a successful in-app fee payment → admin receives a payment alert opening `/payments`. ✅ FR-014.
4. Trigger a wallet top-up/refund → **no** alert. Disable `fee_payment` in alert preferences → no further payment alerts; the in-app bell still records events. ✅ FR-014/FR-017/FR-018.

### 5. AR/EN translation correctness (P3)
1. Walk every primary mobile flow and dashboard screen once in AR, once in EN → no raw keys, no wrong-language fallback, correct RTL. ✅ SC-006.
2. Run the parity guards:
   - Mobile: `flutter gen-l10n` untranslated report shows zero gaps; `app_en.arb` vs `app_ar.arb` key sets match.
   - Dashboard: `npm run check:i18n` (the new `check-i18n-parity.ts`) passes — `en`/`ar` key sets identical, no empty values. ✅ FR-023.

## Tests

```text
cd rideshare-backend && npm test && npm run lint        # incl. new contract tests
cd rideshare && flutter analyze && flutter test
cd rideshare-dashboard && npm run build && npm run check:i18n
```

All new endpoints have contract tests (constitution II); the alert fan-out and seat-template resolver have unit/integration tests written red-green before implementation.
