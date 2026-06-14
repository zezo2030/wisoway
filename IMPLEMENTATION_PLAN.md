# Wisoway — Implementation Plan vs. `requredplan.md`

Date: 2026-04-27
Branch: `007-app-ux-improvements`
Status of audit: based on a full codebase scan against the Arabic requirements file.

This plan only covers what is **missing or partial**. Areas already complete (chat, ratings, Google Maps, base seat layout, localization, base notifications, driver approval gate, one-car-per-driver, base trip CRUD) are not repeated here.

---

## Status Snapshot

| Area | Status | Phase |
|---|---|---|
| Phone-only auth (remove email login) | partial | 1 |
| Device binding / GPS spoofing / fake-account detection | missing | 1 |
| Mandatory driver profile photo enforcement | partial | 1 |
| Booking: multi-seat / companions | missing | 2 |
| Booking: random seat selection | missing | 2 |
| Booking: 3h driver-response timeout | missing | 2 |
| Booking: cancellation windows (24h driver / 12h passenger) | missing | 2 |
| Booking: 5% passenger cancel fee + 10/5% no-show penalties | missing | 2 |
| Booking/Trip status enum overhaul | partial | 2 |
| Trip-time flow (pre-trip confirmations + start trip) | missing | 3 |
| Live GPS family-share link | missing | 3 |
| Recurring trips | missing | 4 |
| Trip stops & notes | missing | 4 |
| Post-payment data reveal gating | missing | 5 |
| In-app calls + phone masking | missing | 5 |
| Payment model decision (Cliq vs cash-only) | needs decision | 5 |
| Admin: ban state, complaints, refund queue | partial | 6 |
| Support / Refund WhatsApp deep link | missing | 6 |
| Social login removal (if strict) | needs decision | 6 |

---

## Open Questions (needs user decision before Phase 5)

1. **Payment model.** The spec says "outside the app (cash / direct agreement)" but the codebase has a fully wired A2A Cliq integration. Keep Cliq for the platform/communication fee, or rip it out and run only cash + wallet for penalty bookkeeping?
2. **Social login.** Google/Facebook OAuth is implemented but the spec implies phone-only. Remove, or keep as optional secondary?
3. **GPS spoofing detection** — server-side only (lat/lng vs IP geo) or also require the Flutter app to send `mockLocation` flags from `geolocator`/`location` plugins?
4. **No-show fees** — deducted from a wallet that the user must top up, or accumulated as a debt subtracted from the next booking like the cancel fee?
5. **Refund flow** — spec says "via WhatsApp" only. Do we still log a refund record server-side (for admin tracking) or is it 100% off-system?

I recommend pausing on Phase 5 until #1–#2 are answered.

---

## Phase 1 — Auth & Profile Hardening

**Goal:** phone-only, OTP-mandatory, device-bound, with hostile-environment detection.

### 1.1 Remove email login/register
- `rideshare-backend/src/modules/auth/auth.controller.ts:42-72` — delete `POST /auth/register` and `POST /auth/login`. Keep `change-password` only if internal admin login still uses email; otherwise remove.
- Drop `SignUpDto` / `SignInDto`.
- `auth.service.ts` — delete `register()` and `login()`. Make `verifyOtp()` the sole new-user creation path.
- Remove `email`/`passwordHash` columns from `UserEntity` if confirmed unused, or mark nullable + keep for admin only. Add migration.
- Flutter: remove email/password screens (`rideshare/lib/screens/auth/login_screen.dart`, signup screen). Make OTP the only entry.

### 1.2 Device binding
- New table `user_devices` (userId, deviceId, fingerprint, platform, fcmToken, firstSeenAt, lastSeenAt, isTrusted, isRevoked).
- `verify-otp` payload accepts `deviceId` + `fingerprint` (Flutter `device_info_plus`). On first verify, mark trusted; on a new device, send security notification to existing trusted devices.
- JWT `sub` claim extended with `deviceId`; reject token if device row revoked.
- Admin endpoint to revoke a device.

### 1.3 GPS spoofing detection
- Flutter side: pass `isMockLocation` from the `geolocator` plugin in trip-create / start-trip / location-update payloads.
- Backend: reject driver location update if `isMockLocation === true`, log to `security_events`. Optional: cross-check claimed lat/lng against IP-based geo-IP (MaxMind GeoLite2) and flag if >100km mismatch.

### 1.4 Fake account detection (lightweight)
- Heuristics service runs on `verifyOtp` register path:
  - Same device fingerprint → N+ accounts in 24h → require manual review
  - Phone number country-code outside JO/allowed list → flag
  - Unusually high signup rate from one IP → throttle + flag
- New table `account_flags` (userId, reason, severity, createdAt) feeding the admin panel.

### 1.5 Mandatory driver photo
- Server: `approveDriver()` in `admin-dashboard.service.ts` rejects if `photoUrl` is null. Same check at trip-create time (additional to existing `isDriverApproved`).
- Flutter: driver onboarding flow blocks "submit for approval" until photo uploaded.
- Migration: backfill — leave existing approved drivers as-is.

**Deliverables:** auth.service refactor, 2 migrations, 2 new entities (`user_devices`, `account_flags`), new `SecurityModule` for spoof/flag logic, Flutter auth flow rewrite, dashboard pages for devices + flags.

---

## Phase 2 — Booking Lifecycle Overhaul

**Goal:** correct status enum, companions, timeouts, cancellation policy, no-show penalties.

### 2.1 Status enums
- New `BookingStatus` enum in `shared.enums.ts`: `PENDING`, `CONFIRMED`, `CANCELLED`, `REJECTED`, `IN_PROGRESS`, `COMPLETED`, `NO_SHOW`.
- Extend `TripStatus`: add `DRAFT`, `PENDING_APPROVAL`, `PUBLISHED` (replaces ACTIVE), `FULLY_BOOKED`, `IN_PROGRESS`. Keep `COMPLETED`, `CANCELLED`. Migration: map existing `active` → `published`.
- `BookingEntity.status` switch from `varchar` to enum.

### 2.2 Companion / multi-seat booking
- New table `booking_seats` (bookingId, seatNumber, passengerName, passengerGender, isMainBooker). Or simpler: add `BookingEntity.seats: jsonb` array of `{seatNumber, gender, displayName}`.
- Drop the unique `idx_bookings_user_trip` constraint (a passenger should be able to book 2 seats: self + companion).
- `CreateBookingDto` accepts `seats: SeatBookingDto[]` (1..N).
- Rewrite `BookingsService.create` to:
  - Validate all seats free + adjacent-gender rule across all requested seats
  - Atomically claim them in `trips.seats` jsonb
  - Compute total price = `seatPriceAtBooking * seats.length`
- Flutter: passenger flow gets a "+ companion" button that adds another seat selection.

### 2.3 Random seat selection
- New endpoint `POST /trips/:id/bookings/auto-seat` that picks N free seats respecting adjacency rule, then funnels into the same create logic.
- Flutter: "اختيار عشوائي" button on seat-selection screen.

### 2.4 3-hour driver-response timeout
- New cron in `JobsModule` (`bookings-timeout.job.ts`) every 5 min:
  - Find bookings where `status = 'pending'` AND `createdAt < now - 3h`
  - Set `status = 'cancelled'`, `cancelledBy = 'system_timeout'`, release seats, notify passenger via push.
- Mark in `notifications.service.ts` a new template `BOOKING_TIMEOUT_CANCELLED`.

### 2.5 Cancellation windows + fees
- New `cancellation-policy.service.ts`:
  - `canDriverCancel(trip)`: `departureTime - now > 24h` else throw.
  - `canPassengerCancel(booking)`: `trip.departureTime - now > 12h` else throw.
- `BookingsService.cancel` calls policy first.
- 5% passenger cancel fee:
  - On a confirmed cancel, create a `pending_charge` row (new entity `pending_charges`: userId, amount, reason, status: pending|applied|waived).
  - On the user's *next* successful booking, deduct + mark applied. Implementation: `BookingsService.create` consults the table before charging.
- Display warning text in Flutter cancel modal — copy from spec line 72.

### 2.6 No-show penalties
- New job `no-show-detector.job.ts` runs at `trip.departureTime + 30min` (driven by per-trip scheduled jobs, not a cron — use `schedule` package or a sweep cron):
  - If trip never started (no `tripStartedAt`) and driver never confirmed presence → driver no-show: 10% of trip total → `pending_charges` to driver.
  - For each confirmed booking where the passenger never confirmed presence (see Phase 3) → passenger no-show: 5% of booking total → `pending_charges` to passenger.
- Booking status moves to `NO_SHOW` for the offending side.

### 2.7 Backfill & wallet wiring
- `pending_charges` resolution can use the existing `WalletService` if the user has a wallet balance — auto-deduct. Otherwise carry forward to next booking.
- Admin dashboard: list of outstanding `pending_charges` with waive button.

**Deliverables:** 3 migrations, 2 new entities (`pending_charges`, optional `booking_seats`), new `CancellationPolicyService`, 2 new jobs, ~6 new notification templates, BookingsService rewrite, BookingsController endpoints `auto-seat` + companion-aware payloads, Flutter: companion picker, random-seat button, cancel-warning modal.

---

## Phase 3 — Trip-Time Flow & Live Tracking

**Goal:** pre-trip confirmations, driver-controlled start, family-shareable live trip.

### 3.1 Pre-trip confirmation cycle
- T-30min cron sends:
  - To passengers: "هل السائق قادم؟" with confirm/deny buttons → updates `BookingEntity.passengerPresenceConfirmedAt`.
  - To driver: per-passenger list "هل تأكدت من حضور <name>؟" → updates `BookingEntity.driverConfirmedPassengerAt`.
- New endpoints:
  - `POST /bookings/:id/passenger-confirm`
  - `POST /bookings/:id/driver-confirm` (driver-only)
- Migration: add the two timestamp columns to `BookingEntity`.

### 3.2 Start trip
- New endpoint `POST /trips/:id/start`:
  - Driver-only. Requires `now >= departureTime - 15min`.
  - Marks trip `IN_PROGRESS`, all confirmed bookings → `IN_PROGRESS`.
  - Bookings with no driver-confirmation can be marked `NO_SHOW` here at driver's discretion (UI checkbox per passenger).
- New endpoint `POST /trips/:id/complete`:
  - Marks trip `COMPLETED`, opens rating window, settles communication fee + payouts.

### 3.3 Family-share live tracking
- New entity `trip_share_links` (id, tripId, token, expiresAt, createdBy).
- New endpoint `POST /trips/:id/share-link` → returns public URL `/share/:token`.
- New public endpoint `GET /share/:token` → returns latest driver location + trip basics (no passenger data).
- Web page: lightweight HTML or React route in dashboard project that polls every 10s and shows on Google Maps.
- Flutter: "مشاركة موقع الرحلة" button on active trip screen → uses `share_plus` to send the link.

**Deliverables:** 2 entities, 4 endpoints, 1 cron, 1 public route, Flutter trip-active screen redesign, dashboard share-page.

---

## Phase 4 — Trip Authoring (Recurrence + Stops + Notes)

### 4.1 Recurring trips
- New entity `trip_recurrence_rules` (id, driverId, templateJson, frequency: daily|weekly, weekdays: int[] bitmask, until: date, lastSpawnAt, isActive).
- Daily cron generates next 7 days of trips per active rule.
- Cancellation: cancel a single occurrence vs. the whole rule (UX choice).

### 4.2 Stops & notes
- Add to `TripEntity`:
  - `stops: jsonb` — `{name, address, lat, lng, order}[]`
  - `notes: text`
- `CreateTripDto` accepts both as optional.
- Flutter: trip-create screen gets a "+ إضافة توقف" repeater + notes textarea.
- Trip-detail screen renders stops on the route map.

**Deliverables:** 1 entity, 1 migration, 1 cron, DTO updates, Flutter trip-create + trip-detail screens.

---

## Phase 5 — Post-Payment Data Reveal & Calls (BLOCKED on payment-model decision)

### 5.1 Data reveal gating
- Define "paid" predicate:
  - If cash-only model: `booking.status === 'CONFIRMED'` is enough (driver implicitly accepted payment offline).
  - If platform fee via Cliq: `booking.passengerPaymentId IS NOT NULL` AND payment status `succeeded`.
- `UsersService.findById` and trip/booking serializers return masked phone (`+962 ** *** 3007`-style) until the paid predicate is true.
- Chat & call endpoints reject with 403 unless paid predicate is true.

### 5.2 Calls
- Decision A — phone with masking: integrate Twilio Voice / Cliq partner with proxy numbers. Flutter dials proxy, server pairs caller→callee.
- Decision B — VoIP: Agora / Daily.co. Cheaper to integrate but needs mic permission UX.
- New `CallsModule`:
  - `POST /calls/initiate` (bookingId) → returns dial number or VoIP token
  - `GET /calls/history`
- New `UserPreferences.hidePhoneNumber: boolean` — when true, masking persists even after payment; calls always go through proxy.

**Deliverables:** masking helper used by all serializers, 1 new module, 1 entity (`call_sessions`), Flutter call button + permission flow.

---

## Phase 6 — Admin, Complaints, Support, Refund

### 6.1 Ban vs deactivate
- Add `UserEntity.banReason: text` and `bannedAt: timestamp` distinct from `isActive`.
- Admin endpoint `POST /admin/users/:id/ban` and `unban`.
- Banned users get a clear "تم حظر حسابك" screen on app open with WhatsApp support link.

### 6.2 Complaints
- New entity `complaints` (id, reporterId, againstUserId, tripId?, bookingId?, category, body, status: open|in_review|resolved|rejected, adminNotes, createdAt, resolvedAt).
- Endpoints `POST /complaints`, `GET /complaints` (admin), `PATCH /complaints/:id`.
- Flutter: "إبلاغ" button on trip detail + post-trip screen.
- Dashboard: complaints page with filtering and resolution flow.

### 6.3 Refund queue (lightweight)
- If we keep refunds in-system: new entity `refund_requests` (bookingId, userId, reason, amount, status, whatsappContactedAt) — admin marks resolved manually after WhatsApp interaction.
- Flutter: refund screen → opens WhatsApp deep link AND posts a `refund_requests` row so admin sees it.

### 6.4 WhatsApp support deep link
- Flutter: existing `support_screen.dart` (commit `7fe575c` already adds it) — confirm it deep-links to `https://wa.me/962788883007?text=...` with prefilled context (userId, latest booking ref).
- "Refund" button uses same deep-link with different prefilled text.

**Deliverables:** 2 entities, ~6 endpoints, dashboard pages (complaints, refunds, ban list), Flutter screens (report, refund), audit existing support_screen.

---

## Cross-Cutting

### Migrations
This plan adds **~10 migrations**. Recommend one migration per phase commit to keep them reviewable.

### Notifications templates to add
- `BOOKING_TIMEOUT_CANCELLED`
- `BOOKING_PRE_TRIP_PASSENGER_CONFIRM`
- `BOOKING_PRE_TRIP_DRIVER_CONFIRM`
- `TRIP_STARTED`
- `TRIP_COMPLETED`
- `NEW_DEVICE_LOGIN`
- `ACCOUNT_FLAGGED`
- `PENDING_CHARGE_APPLIED`
- `COMPLAINT_STATUS_CHANGED`

### Localization
Every new user-facing string lands in both `app_ar.arb` and `app_en.arb`. Dashboard i18n files in `rideshare-dashboard/src/i18n/` similarly.

### Tests
- Unit: cancellation policy, fee calculation, no-show detector, gender adjacency with companions.
- Integration: full booking lifecycle (request → 3h timeout → cancel charge applied to next booking).
- E2E (manual): driver onboarding rejection without photo, family-share link rendering on map.

---

## Suggested Execution Order

1. **Phase 1** (auth/security) — landing this first prevents new bad data and is independent.
2. **Phase 2** (booking) — biggest behavior change; everything downstream depends on the new status enum.
3. **Phase 3** (trip-time) — depends on Phase 2 statuses.
4. **Phase 4** (recurrence/stops/notes) — independent but small; can interleave with 3.
5. **Pause for decisions** on payment model and social login.
6. **Phase 5** (data reveal + calls).
7. **Phase 6** (admin/complaints/support/refund).

Estimated branches: one per phase (`008-auth-hardening`, `009-booking-lifecycle`, …) merged to `main` independently.

---

## Notable Existing Capabilities the Plan Reuses

- `WalletService` & wallet ledger — used for `pending_charges` settlement.
- `JobsModule` (BullMQ-backed) — used for timeouts, no-show, recurrence, pre-trip notifications.
- `NotificationsService` (Firebase + in-app) — used for every new template.
- PostGIS geography on `TripEntity` — already powers nearby trips; reused for spoof distance check.
- `ChatModule` (PostgreSQL-backed, WebSocket gateway) — already supports group + 1-1; just needs payment-gating middleware.
