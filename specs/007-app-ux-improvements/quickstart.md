# Quickstart: Validate App UX Improvements End-to-End

**Feature**: 007-app-ux-improvements
**Audience**: any engineer or QA picking up the feature after it lands on
main; the acceptance scenarios in `spec.md` map to the manual checks below.

This is a manual validation script, executable by a person with a real
Android device, a real iOS device (once iOS push provisioning is complete),
and a running backend. It is intentionally short — contract tests
(`contracts/*`) cover fine-grained assertions; this file verifies the
user-facing story.

---

## Prerequisites

- Backend running locally against a Postgres DB with the new migration
  applied.
- Firebase Admin service-account JSON in `rideshare-backend/config/` (or
  env vars per `.env.example`).
- Flutter app built and installed on at least one real Android device
  signed in as a driver account **and** a real Android (or iOS) device
  signed in as a passenger account. Two devices, two accounts.
- The passenger account has `city = "Amman"` set (either via the new
  `PATCH /users/me` from the app, or directly in the DB for the first
  pass).
- The driver account has `city` set too, but a **different** city
  (`"Irbid"`) to confirm the poster does not notify themselves for the
  fan-out test.

---

## 1. Error-messaging layer (US1, P1)

### 1a. Offline error

1. Put the passenger device in airplane mode.
2. In the app, tap any action that hits the backend (e.g., refresh trip
   list).
3. **Expect**: a single, plain-language toast/dialog in the device's
   locale (Arabic or English) saying something like "You're offline.
   Check your connection and try again."
4. **Fail signals**: `SocketException`, stack trace, HTTP code, or the
   word "Exception" visible to the user.

### 1b. Session-expired error

1. Manually expire the passenger's auth token (revoke in DB, or wait it
   out, or clear the token on device).
2. Perform any authenticated action.
3. **Expect**: "Your session has expired — please sign in again" in the
   current locale, followed by a navigation to the sign-in screen.

### 1c. Server 5xx

1. Point the app at a backend URL that returns 500 (or use a dev toggle).
2. Perform any action.
3. **Expect**: "Something went wrong on our end. Please try again
   later." — no status code, no exception name.

### 1d. Business-rule error

1. As passenger, create a booking that duplicates an existing one.
2. **Expect**: the backend's plain-language rejection reason ("This
   booking already exists or the selected time is taken."), not a
   generic fallback.

### 1e. Developer log capture

1. With the app in debug mode, trigger any of the above.
2. Inspect the developer log stream (IDE, logcat, xcrun).
3. **Expect**: the original exception class, message, and stack trace is
   present in the log, including a correlation id tying it to the
   user-facing toast.

---

## 2. Push notifications (US2, P2)

### 2a. Booking confirmed → passenger

1. As the passenger, book the driver's trip. App permission: grant
   notifications when prompted post-sign-in.
2. As the driver (on device B), confirm the booking.
3. **Expect within 60 seconds**: a push notification on the passenger's
   device titled appropriately, body referencing the booking, in the
   passenger's locale.
4. Tap the notification while the app is backgrounded.
5. **Expect**: the app opens on the booking-details screen for exactly
   that booking.
6. Force-close the app. Trigger another event (e.g., driver cancels the
   booking) and tap the resulting notification from cold-start.
7. **Expect**: the app launches and lands directly on the booking's
   screen, not the home screen.

### 2b. Booking created → driver

1. As a second passenger (third account), book the same driver's trip.
2. On the driver's device, **expect** a push notification "New booking
   on your trip…" within 60 seconds.
3. Tap it. **Expect** a land on that trip's details with the booking
   visible.

### 2c. New trip posted → city fan-out

1. Ensure three test passenger accounts: two with `city = "Amman"`, one
   with `city = "Irbid"`.
2. As the driver (whose own city is `Irbid`), post a new trip with origin
   in Amman.
3. **Expect**: the two `Amman` passenger devices receive a "new trip
   posted" notification within 60 seconds. The `Irbid` passenger and the
   driver themselves receive nothing.
4. Tap a notification. **Expect**: land on the posted trip's details
   page.

### 2d. Permission denied

1. Fresh install. Sign in. When the rationale prompt appears, deny OS
   permission.
2. Perform every flow above.
3. **Expect**: no crashes, no re-prompts, and a clear Settings entry
   explaining how to re-enable notifications.

### 2e. Multi-device

1. Sign the same passenger account in on a phone AND a tablet.
2. As the driver, confirm a booking for that passenger.
3. **Expect**: notification arrives on BOTH devices within 60 seconds.

### 2f. Token invalidation

1. Sign the passenger out on the tablet (but keep phone signed in).
2. As the driver, confirm another booking.
3. **Expect**: only the phone receives the notification. Tablet stays
   silent.

---

## 3. Real route rendering (US3, P3)

### 3a. Real road polyline

1. As a passenger, open a trip's detail/map view for a short urban trip
   (e.g., two streets over).
2. **Expect**: the drawn line between origin and destination follows the
   actual streets — turns, one-ways, etc. Zero straight diagonal lines.

### 3b. Camera framing

1. Same screen.
2. **Expect**: both start and end markers are visible, and the map is
   zoomed/panned to show the full route from first render.

### 3c. Routing failure UX

1. Simulate a routing API failure (disable Directions key, or mock).
2. Open a trip's map.
3. **Expect**: the two markers are still shown; a toast/dialog from the
   US1 error surface says something like "We couldn't load the route.
   Showing pickup and drop-off." — no dashed straight line silently
   substituted with no message.

### 3d. Route refresh on change

1. With a trip open, edit origin/destination (or view a different trip).
2. **Expect**: the polyline re-fetches and redraws for the new
   coordinates. No stale route.

---

## 4. Definition of done checks (quick sanity)

- [ ] `npm test` and `npm run lint` pass in `rideshare-backend`.
- [ ] `flutter analyze` passes in `rideshare`.
- [ ] `grep -r fcmToken rideshare-backend/src/modules/**/dto/` returns no
      hits in serializer/response shapes.
- [ ] A sample API response for `GET /users/me` does not contain any
      field whose name is exactly `token`.
- [ ] Audit sink shows `action='device.register'` and
      `action='device.deregister'` entries for the sessions above.
- [ ] Structured log shows one `event: "notification.dispatch"` line
      per trigger with success/failure counts.

Once all boxes are checked, the feature meets the measurable outcomes in
`spec.md` (SC-001 through SC-008).
