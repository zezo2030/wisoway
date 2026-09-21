# Instant Offer Rich Notification — Design

**إشعار رحلة مباشرة غني (نظام + داخل التطبيق)**

- Status: approved (approach A; system notification + in-app dialog)
- Date: 2026-07-28
- Related: `specs/010-instant-rides/design.md`, existing `BookingNotificationHelper` pattern

---

## 1. Goal

Give drivers the same rich instant-offer experience whether the app is open or in the background:

- System Android notification matching the VisionWay “رحلة مباشرة جديدة” card (route, distance, duration, earnings, trip type, Accept/Reject with countdown).
- In-app dialog restyled to the same visual language (keeping counter-offer).

Reuse the shared-trip booking notification architecture (`RemoteViews` + MethodChannel + FCM intercept).

## 2. Scope

**In**

- Android custom collapsed + expanded notification for `type=instant_offer`
- Accept / Reject actions from the notification (open app → execute existing API)
- Live countdown on the Accept button until `expiresAt`, then auto-dismiss
- Redesigned in-app `_InstantOfferDialog` to match the notification layout
- Extend FCM / push payload with distance, duration, display labels
- Foreground path via MethodChannel (same as booking notifications)
- Background / killed path via `VisionWayMessagingService`

**Out**

- iOS rich custom UI (standard local/FCM notification + open-to-dialog is enough for this pass)
- Full-screen lock-screen Activity (Approach B)
- Persisting distance/duration columns on `instant_ride_requests`
- Changing dispatch / matching / TTL business rules

## 3. Architecture

```
Backend makeOffer
  → NotificationsService.sendPush(type: instant_offer, data: {...enriched})
       ↓
Android (background): VisionWayMessagingService
  → InstantOfferNotificationHelper.show(...)
Flutter (foreground): PushNotificationService
  → MethodChannel → InstantOfferNotificationHelper.show(...)
  → (optional) show InstantOfferDialog if driver home + online

Accept / Reject PendingIntent
  → MainActivity extras: action=accept|decline, offerId, ...
  → Flutter NotificationNavigationService / PushNotificationService
  → InstantRideService.acceptOffer | declineOffer
  → on accept: navigate to TripDetailsScreen
```

### Components

| Unit | Responsibility |
|------|----------------|
| `InstantOfferNotificationHelper` (Kotlin) | Channel, RemoteViews, countdown ticker, notify/cancel |
| `InstantOfferActionReceiver` (Kotlin) | Handle Accept/Reject broadcast → launch MainActivity with action |
| Layouts `notification_instant_*` | Collapsed + expanded UI (RTL, dark theme) |
| `MainActivity` MethodChannel | Add `showInstantOfferNotification` (reuse or extend booking channel) |
| `VisionWayMessagingService` | Intercept `instant_offer` when not foreground |
| `PushNotificationService` (Dart) | Foreground custom show + handle action deep links |
| `_InstantOfferDialog` / extracted widget | Shared visual card for in-app offer |
| `instant-dispatch.service` `makeOffer` | Enrich push data with distance/duration/labels |

## 4. System notification (Android)

### Visual

- Header: green pill “رحلة مباشرة جديدة” + lightning icon; VisionWay + “الآن”
- Body: from (green dot) → dotted connector → to (red pin)
- Stats row: المسافة · المدة التقديرية · الأرباح · نوع الرحلة (مباشرة)
- Footer actions: رفض | قبول (Xs)

Collapsed: badge + from→to + fare one-liner.

### Behavior

- Notification id derived from `offerId` (stable replace/update).
- Reuse existing high-importance channel `rideshare_notifications` (same as booking helper).
- Countdown: Handler updates Accept label every 1s from `expiresAt`; at 0 cancel notification.
- Tap on body (not buttons): open app with `action=open` + `offerId` so Flutter can show the offer dialog / pending offer.
- Accept: `action=accept`, `offerId`.
- Reject: `action=decline`, `offerId`.
- Actions use `PendingIntent` → Activity with extras (immutable flags). Flutter performs API calls (keeps auth/token in Dart).

### Error / edge cases

- Missing fields → show “—” placeholders (same as booking helper).
- Duplicate FCM while ticker running → replace notification, restart ticker from new `expiresAt`.
- Offer already expired on receive (`expiresAt` ≤ now) → do not show.
- After accept/decline from notification → cancel notification immediately.

## 5. In-app dialog

Replace current `AlertDialog` with a dark card matching the notification:

- Same header, route, stats, Accept/Reject + countdown.
- Keep counter-offer (“اقترح سعر”) as secondary control under earnings (not on system notification).
- Polling path (`DriverAvailabilityCard`) continues to open this dialog.
- If FCM arrives while dialog already open for same `offerId` → ignore duplicate.
- If FCM arrives for a new offer while dialog open → ignore until current closes (existing `_offerDialogOpen` guard).

Foreground policy: show dialog when driver UI is active; always show system notification for consistency when app is backgrounded. When app is foreground on driver home, prefer dialog; still OK to skip redundant system notification if dialog is visible (explicit rule: **if dialog shown for offerId, cancel/skip system notification for that offerId**).

## 6. Backend payload

Extend `makeOffer` push `data` (all string values for FCM):

| Key | Notes |
|-----|--------|
| `offerId`, `requestId` | existing |
| `fromName`, `toName` | existing |
| `fareEstimate`, `passengerFare`, `currency` | existing |
| `expiresAt` | ISO string, existing |
| `distanceKm` | haversine from `request.fromPoint` / `toPoint` at offer time |
| `durationMinutes` | heuristic from distance (same speed assumption as pickup ETA helper, ~40–60 km/h trip average) |
| `distanceLabel` | e.g. `95 كم` |
| `durationLabel` | e.g. `1 س 20 د` |
| `earningsLabel` | e.g. `18.00 د.أ` |
| `tripTypeLabel` | `مباشرة` (AR default for push; client may localize later) |

No new DB columns in MVP. Compute from `request.fromPoint` / `toPoint` (and existing fare fields).

## 7. Flutter wiring

- Add `NotificationType.instantOffer = 'instant_offer'` (and cancelled if needed for cleanup).
- Foreground: if `instant_offer` → invoke native helper (mirror booking path).
- Cold start / resume: read intent extras `action` + `offerId`; call accept/decline; clear extras.
- Localization: reuse `instantOfferTitle`, `instantDecline`, accept with countdown; add strings for distance/duration/earnings labels if hardcoded Arabic in layouts is insufficient for EN.

## 8. Testing

- Unit: payload enrichment (distance/duration labels formatting).
- Widget: instant offer dialog shows route, fare, countdown, accept/decline callbacks.
- Android manual: background FCM shows custom UI; Accept opens app and accepts; Reject declines; countdown auto-dismiss.
- Regression: booking_created rich notification unchanged.

## 9. Implementation order

1. Backend payload enrichment
2. Android layouts + helper + receiver + messaging/channel hooks
3. Flutter push + navigation action handling
4. In-app dialog redesign
5. Tests + manual checklist
