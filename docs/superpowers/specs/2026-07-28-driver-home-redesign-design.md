# Driver Home Screen Redesign — Design Spec

**Date:** 2026-07-28  
**Status:** Approved for planning  
**Approach:** Section widgets + new daily-summary API (option 2)  
**Mockup:** `docs/superpowers/assets/2026-07-28-driver-home/driver-home.png`

## Goal

Redesign the driver home tab to match the provided mockup while keeping existing instant-ride, location, trip-list, and create-trip APIs. Add one new backend endpoint that powers the **ملخص اليوم** cards.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | Full visual redesign of driver home content |
| Architecture | Split into section widgets under home/widgets |
| Daily summary data | New backend endpoint (not client-only aggregation) |
| Stats definitions | See API section below |
| Timezone for “today” | `Asia/Amman` (project default) |
| Bottom navigation | Keep existing `HomeScreen` bar; mockup is visual reference only |
| Drawer / menu | Remove hamburger from header; open drawer via avatar tap (keep `onOpenDrawer`) |
| Production graphics | Iconsax + existing vehicle/empty illustrations; no cropped mockup PNGs as icons |
| Passenger home | Out of scope |

## Current context

- `rideshare/lib/screens/home/tabs/driver_home_content.dart` orchestrates header, `DriverAvailabilityCard`, create-trip CTA, location card, and upcoming trips.
- Instant availability uses `InstantRideService` (`getAvailability` / `setAvailability` / heartbeat / pending offer poll).
- Upcoming trips come from `TripProvider.getDriverTripsStream` / `fetchDriverTrips`.
- Location callbacks (`onRefreshLocation`, `onChangeLocation`) and `userLocation` are passed from `HomeScreen`.
- Backend already has `GET /trips/my` for driver trips; no home dashboard summary endpoint today.
- Booking pending accept/reject lives under bookings v2; pending status is usable for “new requests”.

## Architecture

```
HomeScreen (unchanged shell / bottom nav)
└── DriverHomeContent
    ├── DriverHomeHeader
    ├── DriverAvailabilityCard   (restyle UI; same service logic)
    ├── DriverPublishTripCta
    ├── DriverLocationCard
    ├── DriverDailySummaryCard   (GET /trips/my/daily-summary)
    └── DriverCurrentTripsSection
```

### Data flow

1. On open / pull-to-refresh: fetch driver trips (existing) + daily summary (new).
2. Availability card continues to own its online state and timers.
3. Create-trip CTA → `RouteNames.createTrip`.
4. Trip row / empty CTA → trip details or create trip.
5. “عرض الكل” → existing my-trips route.
6. “عرض جميع الإحصائيات” → my-trips (or trip management if already the stats hub); no new analytics screen in this scope.

## UI sections (match mockup)

### 1. Header

- Avatar (photo or default) with small online/status dot when useful.
- Greeting: localized “Hello {firstName}” + subtitle “Ready to receive passengers?” and helper line about publishing / connecting.
- Notification bell with badge (existing `NotificationIconButton`).
- No left hamburger; avatar (or long-press/secondary affordance if needed) calls `onOpenDrawer`.

### 2. Availability card

- Large toggle, status label (online / offline), short description.
- Soft info banner when offline: activate to appear for direct/instant requests.
- Optional car + signal illustration via Iconsax / existing assets.
- **Behavior unchanged:** same InstantRide APIs, heartbeat, offer polling/dialog.

### 3. Publish trip CTA

- Full-width primary teal card: title + subtitle + circular `+`.
- Navigates to create-trip wizard.

### 4. Location card

- “Current location” label + place name from `userLocation`.
- Relative “last updated” copy when refresh timing is available; otherwise omit or show loading.
- Actions: view on map (`onChangeLocation` / map picker as today), refresh GPS (`onRefreshLocation`).

### 5. Daily summary

- Section title “ملخص اليوم”.
- Three compact cards:
  - New requests (`newRequests`) — needs response
  - Today’s trips (`todayTrips`) — published today
  - Bookings (`todayBookings`) — total non-cancelled on today’s trips
- Footer link “عرض جميع الإحصائيات” → my trips.
- Loading/error: skeleton or inline retry; do not block the rest of the home scroll.

### 6. Current trips

- Title “رحلاتك الحالية” + “عرض الكل”.
- Up to 5 upcoming non-completed/cancelled trips (same filter spirit as today: departure after now−2h).
- Empty state: illustration + “لا توجد رحلات منشورة” + CTA “انشر رحلة الآن”.
- Non-empty: reuse / lightly restyle existing `TripCard`.

## API — `GET /trips/my/daily-summary`

**Auth:** JWT + role `driver`  
**Route placement:** on `TripsController` **before** `@Get(':id')` routes (same pattern as `GET /trips/my`).

### Response

```ts
{
  newRequests: number;
  todayTrips: number;
  todayBookings: number;
  timezone: string; // e.g. "Asia/Amman"
  date: string;     // YYYY-MM-DD in that timezone
}
```

### Definitions

| Field | Meaning |
|-------|---------|
| `newRequests` | Count of bookings with status `pending` on trips owned by the current driver (any departure day). These need accept/reject. |
| `todayTrips` | Count of the driver’s trips whose `departureTime` falls on the current calendar day in `Asia/Amman`, excluding `cancelled` (and typically excluding fully `completed` if product treats them as past — **lock:** exclude `cancelled` only; include scheduled/active/completed that departed today). |
| `todayBookings` | Count of bookings on those same “today” trips where status is **not** `cancelled`. |

### Implementation notes

- Prefer aggregate SQL / QueryBuilder counts (not loading full trip graphs).
- Unit-test the three counters with fixed “now” / timezone boundaries.
- Mobile: add thin client method on trip service/provider; cache last payload until next refresh.

## Error handling

| Case | Behavior |
|------|----------|
| Summary request fails | Show section error/retry; rest of home still works |
| No trips | Summary zeros + empty current-trips state |
| Location unknown | Location card shows determining/placeholder copy |
| Availability toggle fails | Existing `ErrorSurface` |

## Testing

- Backend unit: daily-summary counts for pending / today trips / today bookings; timezone day boundary.
- Flutter: widget/smoke for section composition; provider/service parses summary DTO.
- Manual: match mockup layout RTL; toggle online; create trip CTA; empty vs populated trips.

## File touch list (indicative)

**Backend**

- `trips.controller.ts` — new route
- `trips.service.ts` — `getDailySummary(driverId)`
- `trips.service.spec.ts` — counter tests

**Mobile**

- `driver_home_content.dart` — orchestrator only
- New/updated widgets under `screens/home/widgets/`
- Restyle `driver_availability_card.dart` UI
- `trip_service.dart` / `trip_provider.dart` — fetch summary
- `app_ar.arb` / `app_en.arb` — greeting, summary labels, empty-state copy

## Out of scope

- Redesigning passenger home or bottom nav structure
- Full analytics / historical stats screen
- New instant-ride protocol
- Shipping cropped icons from the mockup PNG
- Changing create-trip wizard (already shipped)

## Assets

- Reference mockup: `docs/superpowers/assets/2026-07-28-driver-home/driver-home.png`
- Prefer existing `rideshare/assets/images/...` vehicle/empty art where it fits the empty state
