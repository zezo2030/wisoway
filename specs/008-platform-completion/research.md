# Phase 0 Research — Platform Completion

**Date**: 2026-04-27
**Branch**: `008-platform-completion`

The five scope-shaping ambiguities raised in `/speckit.specify` were resolved in the `/speckit.clarify` session (recorded under `## Clarifications` and `## Resolved Clarifications` in [`spec.md`](./spec.md)). What remains are implementation-pattern choices that the spec deliberately left to the engineering team. This document records each decision with rationale and rejected alternatives.

---

## R-001 — Job scheduler for time-driven workflows

**Context**: Several flows are time-driven: 3-hour pending-booking timeout (FR-024), 30-minute pre-trip confirmation (FR-031), no-show detector at `departureTime + 30 min` (FR-027), recurring-trip occurrence spawner (FR-013). Existing project code already pulls in BullMQ via `@nestjs/bull` and Redis (used for chat presence and existing notification scheduling).

**Decision**: BullMQ for all four flows. Use one queue per concern (`bookings-timeout`, `pre-trip-confirm`, `no-show`, `recurrence-spawn`). Booking-timeout and no-show are scheduled per-record at the moment the precipitating event occurs (booking created → enqueue with 3h delay; trip created → enqueue at `departureTime + 30 min`). Pre-trip-confirm and recurrence-spawn are repeating jobs (cron-style) that sweep the database for due rows.

**Rationale**:
- Already a project dependency — no new infrastructure.
- Per-record delayed jobs eliminate the database-sweep window error that pure cron sweeps suffer from (a 5-minute cron can fire up to 5 minutes late).
- Per-record jobs are individually cancellable: when a booking is accepted, we remove its timeout job — no need for the worker to re-check status on dequeue (still re-checks defensively).

**Alternatives considered**:
- **Cron-only sweep** (`@nestjs/schedule`): simpler but introduces up-to-the-cron-window latency. Acceptable for pre-trip (already a 2-minute SC tolerance per SC-007) but unacceptable for the 3-hour timeout if we want the SC-003 60-second-after-deadline notification target.
- **`pg_cron` / database-triggered**: removes Redis dependency but couples scheduling to the primary store and adds operational complexity unfamiliar to this team.

---

## R-002 — Public share-link tokenization

**Context**: FR-035 / FR-036 require a public read-only link — viewable without an app or login — that shows the in-progress driver location, hides PII, and stops updating after trip completion.

**Decision**: Opaque random token (32-byte URL-safe), stored in a new `trip_share_links` table (`tripId`, `token`, `createdBy`, `createdAt`, `expiresAt`). Public route `GET /share/:token` returns: `{ status: 'in_progress' | 'completed' | 'cancelled', driverLocation?: { lat, lng, capturedAt }, etaMinutes?, fromName, toName }`. The route is rate-limited per-token (Redis bucket, 1 request/sec, 60 burst). Token never appears in logs in plaintext — only its first 8 chars suffix. The dashboard reuses the same JSON to render the live page (or, alternatively, the page is a small static HTML/JS file served from `rideshare-backend/public/share.html` that polls the same JSON endpoint).

**Rationale**:
- A stateless JWT was rejected because we need server-side revocation (when the trip ends, the token must stop working — easier with a row that we can flip a flag on, no signature-replay risk).
- An opaque token is easier to rotate if abuse is detected.
- No PII in the response keeps Constitution IV obligations clean.

**Alternatives considered**:
- **Signed JWT in URL**: stateless but no revocation. Combined with the trip-completed check at the DB level it could work, but introduces signing-key management for a feature that doesn't need it.
- **Short numeric code (6-digit)**: too easy to brute-force.

---

## R-003 — In-app calling provider with phone-number masking

**Context**: FR-040 requires a way to place a phone call between driver and passenger after settlement, optionally hiding the real number on either side.

**Decision**: Use **Twilio Voice with Programmable Numbers** for masked calls. We already use Twilio for SMS OTP, so account, billing, and ops are familiar. Implementation pattern:
- A pool of Twilio JO (or international DID) numbers is provisioned in advance.
- When a call is initiated by either party for a settled booking, the backend allocates an available proxy number, creates a Twilio TwiML route that bridges the caller's real number to the callee's real number, and returns the proxy number to the calling client.
- The mobile client launches the system dialer with the proxy number (Flutter `url_launcher` for `tel:`).
- The proxy number is reused for the full booking lifecycle (deallocated on trip-completed-plus-24h).
- If the user has `hidePhoneNumber` set, the *display* on the other side shows the proxy number instead of the real one and the bridging logic is unchanged.

**Rationale**:
- Twilio already in the dependency tree.
- Proxy-DID model is a well-trodden pattern for rideshare and matches Spec lines 138–141 precisely.
- No need for VoIP / WebRTC in the mobile app — calls go through PSTN, which uses zero app-side mic permissions and zero data.

**Alternatives considered**:
- **VoIP (Agora / Daily / Twilio Programmable Voice via WebRTC)**: lower per-minute cost but requires mic-permission UX, in-call screen, codec management, and handling for poor-network scenarios. Disproportionate complexity for the spec.
- **Plain `tel:` dial without masking**: rejected because Spec explicitly lists "hide phone number" as an option (line 141).
- **WhatsApp call deep-link**: would push users off the platform and bypass the contact-reveal gating model.

**Operational note**: Provisioning Jordanian DID numbers via Twilio requires regulatory paperwork; the team should kick this off as soon as Phase 5 starts (typically a 2–4 week lead time). Fallback: a small pool of US/UK DIDs covers the spec while the JO pool is being provisioned.

---

## R-004 — Device-fingerprint storage and matching

**Context**: FR-003 / FR-007 require recording the device used at OTP verification and flagging accounts where one device registers many accounts.

**Decision**: Store a SHA-256 hash of `(platform || ':' || deviceId || ':' || installSalt)` where:
- `platform` = `ios` | `android` | `web`
- `deviceId` = stable platform identifier from `device_info_plus` (Flutter): `androidId` on Android API 26+ or `idfv` on iOS. Web falls back to a localStorage UUID.
- `installSalt` = the user-id-independent server-issued opaque salt set on first contact, returned to the client to persist; rotated only on factory reset.

Stored on `user_devices` as `fingerprintHash` plus a denormalized `platform` column for queries. Multi-account detection: count `DISTINCT userId` per `fingerprintHash` over a rolling 24-hour window — when count > N (configurable, default 3), the *next* registration creates the user in `restricted=true` state and writes an `account_flags` row.

**Rationale**:
- Hashed fingerprints satisfy Constitution IV (no raw device IDs in logs or admin queries by default; admin can request the hash plus platform, never the raw ID).
- Heuristic is simple, explainable to admins, and the threshold is tunable without code change.
- Hashing protects against device-ID rotation: legitimate factory resets generate a new hash; the old data ages out of the rolling window naturally.

**Alternatives considered**:
- **FingerprintJS-style passive fingerprinting**: too invasive for a regional rideshare app; raises GDPR/PDP concerns; overkill for the threshold-based heuristic the spec describes.
- **No fingerprinting, IP-based only**: false-positive rate too high in markets where shared NAT (e.g., student housing, cafes) is common.

---

## R-005 — Server-side rejection of mocked location

**Context**: FR-006 requires rejecting client-reported location updates that the client has self-flagged as mocked, and recording the event.

**Decision**: Mobile clients pass an `isMockLocation` boolean field on every location update payload (sourced from the Flutter `geolocator` plugin's `Position.isMocked` on Android; iOS does not expose this — set `false`). Backend `LocationGuardInterceptor`:
- Rejects with `403` when `isMockLocation === true` for any driver-side endpoint that touches trip status (`location updates`, `start trip`, `complete trip`).
- Writes a `security_events` row (`type=mock_location`, `userId`, `tripId?`, `payload`, `createdAt`).
- Notifies confirmed passengers on the affected trip if it's in progress (FR-049's "trip cancelled" template — no need for a brand-new template; the event practically means the trip cannot continue).
- After 3 events from the same driver in 30 days, raise an `account_flags` row of severity `high` for admin review.

**Rationale**:
- Spec scope is explicitly server-side rejection of *client-self-flagged* mocks (per the Assumptions section). Deeper anti-cheat (root/jailbreak detection, OS-level forgery) is out of scope.
- Three-strikes flagging keeps admin queue noise low while preserving the audit trail.

**Alternatives considered**:
- **GeoIP cross-check**: rejected — rural Jordan has poor IP-geolocation accuracy (carrier-grade NAT often resolves to Amman regardless of actual location). Would generate too many false positives.
- **Hard-block driver entirely on first mock event**: rejected as too aggressive — a single false positive from a buggy client could lock a working driver out of income.

---

## R-006 — Hybrid pending-charge collection mechanic

**Context**: CLAR-003 chose a hybrid wallet-deduct-then-carry-forward policy. Implementation needs an explicit ordering and atomicity story.

**Decision**: When a `PendingCharge` is created, a synchronous transaction:
1. Locks the user's wallet account row.
2. If `wallet.balance >= charge.amount`, post a `WalletTransaction` of type `ADJUSTMENT` direction `DEBIT` and mark the charge `applied` (with `walletTransactionId` set).
3. Else, leave the charge `pending`.
4. Commit.

On the next successful booking transaction (the moment the booking goes from `Pending` to `Confirmed`, OR — for bookings with platform-fee-paid in-app — at fee settlement), check for outstanding `pending` charges for the user:
- For each outstanding charge: attempt the same wallet-debit; if wallet is empty, add the charge amount to the booking's transaction (collect from the in-app fee payment if one is being made; otherwise increment the next platform-fee-due figure).

Edge: if the user never books again, the charge remains pending. Admin can `waive`. Per SC-005 we track the proportion unresolved beyond 30 days.

**Rationale**:
- Single transaction at the charge moment keeps wallet ledger correct and avoids double-counting.
- Carry-forward at next-booking time (rather than a sweep job) collects exactly when the user is most likely to top up, without polling overhead.

**Alternatives considered**:
- **Separate sweep cron that retries wallet-debit nightly**: adds traffic and complicates the wallet event log; the next-booking trigger is sufficient.

---

## R-007 — Companion identity persistence

**Context**: A multi-seat booking carries N seats, each potentially representing a companion who is not an app user. We must store enough to: (a) display in seat layout, (b) attribute no-show to the right party (the booking holder, not the companion — Spec says "passenger" no-show penalty), and (c) support the gender-adjacency rule.

**Decision**: New child entity `BookingSeat` (`bookingId`, `seatNumber`, `displayName`, `gender`, `isMainBooker`). Companions are NOT separate `User` records. The penalty (no-show 5%) is recorded against the booking's `userId` (the main booker), regardless of which specific seat the driver flagged as not-present.

**Rationale**:
- Companions are by definition not app users, so giving them a `User` record would corrupt the active-user count in admin stats and would create login paths that don't exist.
- The booker is responsible for the booking — penalizing them aligns with how cash payment works (the booker pays for everyone).
- Gender-adjacency rule reads from `BookingSeat.gender` directly.

**Alternatives considered**:
- **Companion as `User` record**: rejected per above.
- **Companions stored as JSONB on `Booking`**: simpler write, but gender-adjacency queries become ugly and a child table makes audit trails clearer.

---

## R-008 — Trip status enum migration without breaking deployed mobile clients

**Context**: Mobile floor clients see today's `TripStatus` (`active`, `hidden`, `completed`, `cancelled`). New values: `draft`, `published` (replaces `active`), `fully_booked`, `in_progress`. Constitution I requires the contract to remain compatible.

**Decision**: Migration plan in three steps spread across Branches 2–3:
1. **Additive migration**: extend the database enum with the new values; map `active → published` in a backfill UPDATE; keep the response serializer mapping `published → active` for one release so old mobile clients see the familiar value.
2. **Mobile rollout**: ship the mobile update that recognizes the new statuses; gate behind a min-app-version flag enforced server-side.
3. **Drop compatibility shim**: remove the `published → active` shim in a follow-up release once the deployed mobile floor is past the gate.

**Rationale**:
- Matches the Constitution governance section on additive-safe migrations.
- Avoids a coordinated big-bang deploy that would couple backend release to app-store review timing.

**Alternatives considered**:
- **Big-bang**: rejected on Constitution grounds.

---

## Open implementation items (deferred to /speckit.tasks)

These are not blocking for Phase 1 design but should appear in the task list:

- WhatsApp deep-link string format (web vs. mobile detection: `https://wa.me/962788883007?text=…` works on both, but iOS sometimes needs `whatsapp://send?phone=…&text=…` to avoid a web fallback). Decided at task time.
- Refund-record retention policy (probably 2 years to match financial-record norms; confirm with operations).
- The exact min-app-version gate value for the trip-status-enum compatibility shim removal — set in Branch 3 once Branch 2 is merged.

These will be flagged as TODOs in `tasks.md` rather than blocking the plan.

---

## R-009 — WhatsApp deep-link format for cross-platform support (T183)

**Context**: The support screen (and any future passenger-to-driver WhatsApp prompt) needs a deep link that opens WhatsApp and pre-fills a message. The open item noted two candidate schemes: the universal `https://wa.me/…` link vs. the iOS-specific `whatsapp://send?phone=…&text=…` URI scheme.

**Decision**: Use `https://wa.me/{E164_number}?text={urlEncodedMessage}` exclusively on both iOS and Android.

**Rationale**:
- `https://wa.me/…` is the canonical link format documented by Meta. On iOS 16+ it opens the WhatsApp app directly if installed, falling back to the App Store gracefully. On Android the OS intent resolver opens WhatsApp when installed.
- `whatsapp://send?…` is a custom URI scheme that iOS may route to Safari when WhatsApp is not the registered handler, surfacing a blank error page — worse UX than the web fallback.
- Flutter `url_launcher` handles `https://wa.me/…` via `launchUrl(Uri.parse(url))` with no additional platform config.
- Confirmed in `rideshare/lib/screens/settings/support_screen.dart`: the support screen already uses this format (`https://wa.me/$_whatsAppNumber?text=$prefill`). No code change required.

**Alternatives considered**:
- **`whatsapp://send?phone=…&text=…`**: rejected — unreliable on iOS when the user has not registered WhatsApp as the default handler; the web fallback degrades the experience.
- **Platform-conditional URL** (iOS → `whatsapp://`, Android → `https://wa.me/`): adds code complexity for no meaningful gain; the universal link handles both.

---

## R-010 — Refund-record retention policy (T184)

**Context**: The `refund_requests` table (created in migration 008.10) stores records of passenger refund requests. Financial record-keeping regulations vary by jurisdiction; the team asked for a concrete retention figure.

**Decision**: Retain all `refund_requests` rows for **2 years** from `createdAt`, then archive (move to a cold-storage table or an S3-backed data warehouse export) rather than hard-delete.

**Rationale**:
- Jordan's Income Tax Law and general commercial accounting norms require financial records to be kept for 7 years; however, individual refund-request rows are supporting evidence, not primary accounting records. Two years satisfies operational audit needs (chargebacks, disputes) with a comfortable margin.
- Archiving rather than deleting preserves recoverability if a regulatory query arrives after the live-table retention window.
- The 2-year window aligns with the typical credit-card chargeback dispute period (18 months for Visa/Mastercard) plus a 6-month buffer.

**Implementation note**: A scheduled cleanup job (`refund-archive` BullMQ queue, monthly cron) should SELECT rows older than 2 years and INSERT them into a `refund_requests_archive` table before deleting from the live table. Add this to the operational runbook; it is not in Phase 9 scope but should be ticketed before the platform goes live at scale.

**Alternatives considered**:
- **7-year retention in live table**: legally conservative but creates operational overhead (index bloat, backup size) for a table that will grow continuously.
- **Hard-delete at 2 years**: rejected — eliminates recoverability; archiving costs are negligible (append-only cold table or parquet export).

---

## R-011 — Performance targets and measurement approach (T186)

**Context**: Several spec success criteria (SC-008: search P95 ≤ 200 ms; SC-009: booking-create P95 ≤ 500 ms; SC-010: push notification delivery ≤ 5 s P95) require instrumentation before the final platform release.

**Decision**: Use NestJS's built-in `APP_INTERCEPTOR` hook with a lightweight `PerformanceInterceptor` that records response time per route and emits a structured log line (`{ route, method, statusCode, durationMs, traceId }`). Aggregate with the existing log-shipping pipeline (stdout → CloudWatch / Datadog). No APM SDK added at this phase — the structured log line is sufficient for P95 queries via log analytics.

For push notification delivery latency (SC-010), record `enqueuedAt` on the `notifications` job payload and `deliveredAt` (set by FCM delivery receipt webhook or Firebase Admin SDK async callback) in a new `notification_delivery_log` table. The 5-second P95 is measured from `enqueuedAt` to `deliveredAt`.

**Rationale**:
- Adding a full APM SDK (Datadog, New Relic) now would require agent config, billing approval, and key management. For a v1 platform these are premature; structured logs give the same query capability at zero marginal cost.
- Per-request structured logging also feeds the `correlationId` field added in T187 — all rows (DB audit, HTTP log) for a request share the same trace ID.

**Alternatives considered**:
- **OpenTelemetry + Jaeger**: technically superior for distributed tracing but adds infrastructure (Jaeger collector/backend) and SDK integration burden that is out of scope for Phase 9.
- **Database-level timing only (EXPLAIN ANALYZE)**: useful for query tuning but does not capture network + serialization overhead; the route-level interceptor covers the full stack.
