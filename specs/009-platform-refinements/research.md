# Phase 0 Research: Platform Refinements

**Feature**: 009-platform-refinements
**Date**: 2026-06-14

This document resolves the open technical choices for the five refinements. The cross-cutting product ambiguities were already resolved in the spec's Clarifications session (2026-06-14); what remains are implementation-approach decisions, recorded below in Decision / Rationale / Alternatives form.

---

## R1 — Admin web-push channel for the dashboard

**Decision**: Use **Firebase Cloud Messaging for Web (FCM Web)**. The dashboard registers a web push token via the Firebase JS SDK and a `firebase-messaging-sw.js` service worker; the backend sends to those tokens through its **existing Firebase Admin SDK** (`admin.messaging()`), the same path already used for mobile FCM.

**Rationale**:
- The backend already initializes Firebase Admin SDK and has a working `sendPush` / multicast path and a `DeviceTokenEntity` registration pattern — FCM Web reuses all of it. A web token is just another token kind for `admin.messaging().send()`.
- Avoids standing up a second, parallel push stack (VAPID keys, `web-push` library, subscription storage, payload encryption) when one already exists.
- FCM Web delivers background notifications via the service worker even when the dashboard tab is closed, satisfying "on mobile" (mobile browser) and desktop equally.
- Deep-linking to `/users/:id` and `/payments` is straightforward via the notification `click_action` / `data` payload handled in the service worker.

**Alternatives considered**:
- **Standalone Web Push API + VAPID (`web-push` npm)**: fully standard and Firebase-free, but duplicates infrastructure the backend already has and adds new key management. Rejected to minimize new infra (constitution: simplicity).
- **Socket.IO only (already present)**: real-time while a tab is open, but does **not** survive tab/browser closure, so it fails the core "alert me when I'm not watching the dashboard" need. Kept as the in-app complement, not the primary channel.

**Implementation notes**: store the web token as a `device_tokens` row with `platform = 'web'` (or a dedicated `web_push_token` table — see data-model). Gate registration behind admin auth. Required env: Firebase web config (apiKey, projectId, messagingSenderId, appId) and the FCM Web Push certificate (VAPID public key) for `getToken({ vapidKey })`.

---

## R2 — Location autocomplete provider & integration pattern

**Decision**: Use **Google Places Autocomplete**, proxied through a **new backend endpoint** (`GET /locations/autocomplete` + `GET /locations/place/:id`). The mobile client never holds the Places key; it calls the backend, which calls Google with a server-side key, applies **session tokens**, language, and region bias, and caches results briefly.

**Rationale**:
- The app already uses Google Maps Platform (`google_maps_flutter`, `geocoding`), so Places is the consistent, already-provisioned provider; place IDs returned by autocomplete resolve to coordinates the existing map flow understands.
- A backend proxy keeps the API key server-side (constitution IV — keys must not ship to clients), enables central rate-limiting and short-TTL caching to control cost, and lets both mobile and (future) dashboard reuse one endpoint.
- Session tokens group keystroke-level autocomplete calls + one details call into a single billable session, materially reducing cost.
- Region bias + language param give AR/EN, in-region suggestions (FR-007).

**Alternatives considered**:
- **Client-side Places (e.g. `google_places_flutter`)**: simplest to wire, but exposes/relies on an on-device key (restrictable by bundle id, but still weaker), no shared caching, and harder cost control. Rejected on security + cost-control grounds.
- **Mapbox / OpenStreetMap (Nominatim/Photon)**: removes Google dependency but introduces a second mapping provider inconsistent with the existing map SDK and coordinate flow. Rejected for consistency.

**Implementation notes**: debounce keystrokes (~250–300 ms) and enforce a minimum trigger length (≥2 chars) client-side to limit calls; backend caches `(query, lang, region)` for a short TTL; graceful no-results and offline/error states fall back to the existing tap-on-map picker (FR-008).

---

## R3 — Vehicle-type → seat-layout template source of truth

**Decision**: Introduce a **canonical vehicle-type catalog on the backend** (a typed config module, `vehicles/vehicle-types.ts`, optionally mirrored by a seed table), mapping each supported vehicle type to a default `SeatLayout` template. Expose it read-only via `GET /vehicles/types`. The mobile client auto-applies the matching template when a vehicle type is selected (still editable for irregular layouts); trip creation continues to resolve seats from the vehicle's **stored** layout.

**Rationale**:
- `vehicleType` is currently a free string and seat layout is entered fully manually — there is no single definition of "a 7-seat van's layout." A backend catalog makes the mapping authoritative and consistent across clients and server defaults.
- Keeping the catalog server-side means the existing server-side `resolveVehicleSeatLayout()` can fall back to the template when a vehicle has no explicit layout, and future vehicle types are added in one place.
- Mobile auto-applies for instant UX (FR-009) while preserving the ability to customize irregular arrangements (the existing custom-layout path), and the offered seats still match exactly what gets stored (FR-011).

**Alternatives considered**:
- **Mobile-only constant map**: instant and offline, but duplicates truth on each client and drifts from the server's seat resolution. Rejected; instead the mobile keeps a small mirror seeded from `GET /vehicles/types` for offline prefill, with the backend as source of truth.
- **Free-form per-vehicle only (status quo)**: no auto layout; fails FR-009/FR-012. Rejected.

**Implementation notes**: define the supported set (sedan, SUV, van, truck, bus, motorcycle — already in mobile `app_constants.dart`) each with `{ seats, rows, seatsPerRowList }`. A type lacking a template falls back to a sensible default and is flagged (FR-012). Changing the type replaces the layout (FR-010).

---

## R4 — Approval-status freshness mechanism (mobile)

**Decision**: Implement the clarified behavior — **re-fetch the driver profile (`GET /users/me`) when the create-trip flow is opened and when the app returns to the foreground** — by (a) adding a `WidgetsBindingObserver` that calls `AuthProvider.loadUserProfile()` on `AppLifecycleState.resumed`, and (b) awaiting a profile refresh at the entry of the create-trip gate before evaluating `canCreateTrips`.

**Rationale**:
- Root cause confirmed: `AuthProvider` loads the profile once at startup (`checkAuthState()`), caches `isDriverApproved`, and never refreshes — and there is no lifecycle observer. The bug is purely stale local state.
- Re-checking at the decision point (and on foreground) guarantees freshness exactly where it matters without a real-time channel or background polling (clarification chose this over push/poll), so it is the lowest-cost correct fix. The same refresh re-blocks a revoked driver (edge case / FR-004).

**Alternatives considered**:
- **Real-time push of approval**: best-feeling UX but requires a new push event + client handling; the clarification explicitly chose the simpler on-entry/foreground re-check.
- **Periodic polling**: unnecessary battery/network cost for an infrequent state change; rejected per clarification.

**Implementation notes**: guard against redundant concurrent refreshes; show a brief loading state if the gate is awaiting the refresh; no backend change required (the endpoint already returns `isDriverApproved`).

---

## R5 — Translation completeness & correctness detection

**Decision**: Treat the sweep as (1) a one-time manual AR/EN walkthrough of every primary flow on both clients, plus (2) an automated **key-parity guard** per client that fails when AR and EN key sets diverge or values are empty:
- **Mobile**: rely on `flutter gen-l10n` (untranslated messages report) plus a small check comparing `app_en.arb` vs `app_ar.arb` key sets; surface hardcoded user-facing strings via review.
- **Dashboard**: add `src/scripts/check-i18n-parity.ts` that parses `src/i18n/translations.ts` and asserts the `en` and `ar` maps have identical keys and no empty values; wire into the build/CI.

**Rationale**:
- The clarification scoped this to mobile + dashboard. Both already have a working i18n setup, so the risk is *missing/empty* entries and future drift, not a new framework. A parity guard makes FR-023 (missing strings must be detectable) enforceable and prevents regressions after this pass.
- Mobile uses `.arb` + gen-l10n (which already emits an untranslated-messages report); dashboard uses a single TS file, so a tiny parity script is the pragmatic equivalent.

**Alternatives considered**:
- **Manual review only**: catches today's gaps but not tomorrow's — fails the "detectable going forward" requirement. Rejected.
- **Adopt a heavyweight i18n linter/service**: over-engineered for two small resource sets. Rejected (YAGNI).

**Implementation notes**: the dashboard parity script is the only net-new tooling; the mobile check can reuse gen-l10n config (`untranslated-messages-file`). RTL is already handled on both clients; the walkthrough verifies it rather than building it.

---

## Summary of decisions

| # | Area | Decision |
|---|------|----------|
| R1 | Admin web push | FCM **Web** via existing Firebase Admin SDK; token stored as `device_tokens` (platform=web) |
| R2 | Location autocomplete | Google Places **proxied by backend** (`/locations/autocomplete` + `/locations/place/:id`), session tokens, key server-side |
| R3 | Seat layout by type | Backend **vehicle-type catalog** (`GET /vehicles/types`); mobile auto-applies template; server stays source of truth |
| R4 | Approval freshness | Mobile re-fetch `/users/me` on **create-flow entry + app foreground** (no backend change) |
| R5 | i18n correctness | Manual AR/EN walkthrough + **key-parity guard** per client (gen-l10n report + dashboard parity script) |

All items are resolved; no `NEEDS CLARIFICATION` remain. Proceed to Phase 1.
