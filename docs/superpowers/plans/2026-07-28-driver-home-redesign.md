# Driver Home Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the driver home tab to match the mockup and power **ملخص اليوم** from `GET /trips/my/daily-summary`.

**Architecture:** Keep `HomeScreen` / bottom nav. Split `DriverHomeContent` into section widgets. Add a TripsService aggregate for daily summary (`Asia/Amman`). Mobile fetches summary via TripService/TripProvider without changing instant-ride or create-trip APIs.

**Tech Stack:** NestJS 11 / TypeORM / Jest; Flutter 3.9 / Dart 3 / Provider / Iconsax

**Spec:** `docs/superpowers/specs/2026-07-28-driver-home-redesign-design.md`  
**Mockup:** `docs/superpowers/assets/2026-07-28-driver-home/driver-home.png`

## Global Constraints

- Full visual redesign of driver home only; passenger home out of scope
- Keep InstantRide / location / trip-list / create-trip APIs
- Daily summary from new backend endpoint (not client-only aggregation)
- Timezone for “today”: `Asia/Amman`
- Bottom nav unchanged
- Header: no hamburger; avatar opens drawer (`onOpenDrawer`)
- Iconsax + existing assets; no cropped mockup PNG icons
- Do not commit unless the user explicitly asks

---

## File map

| File | Responsibility |
|------|----------------|
| `rideshare-backend/src/modules/trips/driver-day-bounds.ts` | Pure `Asia/Amman` day bounds helper |
| `rideshare-backend/src/modules/trips/driver-day-bounds.spec.ts` | Unit tests for day bounds |
| `rideshare-backend/src/modules/trips/trips.service.ts` | `getDailySummary(driverId)` |
| `rideshare-backend/src/modules/trips/trips.controller.ts` | `GET my/daily-summary` before `:id` |
| `rideshare-backend/src/modules/trips/trips.service.spec.ts` | Summary count tests |
| `rideshare-backend/src/modules/trips/trips.module.ts` | Register `BookingEntity` if injecting its repo |
| `rideshare/lib/models/driver_daily_summary.dart` | DTO |
| `rideshare/lib/core/api/api_endpoints.dart` | Path constant |
| `rideshare/lib/core/services/trip_service.dart` | `getDriverDailySummary()` |
| `rideshare/lib/providers/trip_provider.dart` | Cache + fetch summary |
| `rideshare/lib/l10n/app_ar.arb` + `app_en.arb` | Copy |
| `rideshare/lib/screens/home/widgets/driver_home_header.dart` | Header |
| `rideshare/lib/screens/home/widgets/driver_publish_trip_cta.dart` | Green CTA |
| `rideshare/lib/screens/home/widgets/driver_location_card.dart` | Location |
| `rideshare/lib/screens/home/widgets/driver_daily_summary_card.dart` | Stats |
| `rideshare/lib/screens/home/widgets/driver_current_trips_section.dart` | Trips / empty |
| `rideshare/lib/screens/home/widgets/driver_availability_card.dart` | Restyle UI only |
| `rideshare/lib/screens/home/tabs/driver_home_content.dart` | Orchestrator |

---

### Task 1: Day bounds helper (`Asia/Amman`)

**Files:**
- Create: `rideshare-backend/src/modules/trips/driver-day-bounds.ts`
- Create: `rideshare-backend/src/modules/trips/driver-day-bounds.spec.ts`

**Interfaces:**
- Produces:

```ts
export const DRIVER_HOME_TIMEZONE = 'Asia/Amman';

export type DayBounds = {
  /** Inclusive UTC start of the calendar day in [timeZone]. */
  startUtc: Date;
  /** Exclusive UTC end of that calendar day. */
  endUtc: Date;
  /** `YYYY-MM-DD` in [timeZone]. */
  date: string;
};

export function calendarDayBoundsInTimeZone(
  timeZone: string,
  now?: Date,
): DayBounds;
```

- [ ] **Step 1: Write failing tests**

```ts
import {
  calendarDayBoundsInTimeZone,
  DRIVER_HOME_TIMEZONE,
} from './driver-day-bounds';

describe('calendarDayBoundsInTimeZone', () => {
  it('returns Amman calendar date for a known UTC instant', () => {
    // 2026-07-28 21:30 UTC = 2026-07-29 00:30 in Asia/Amman (UTC+3)
    const now = new Date('2026-07-28T21:30:00.000Z');
    const bounds = calendarDayBoundsInTimeZone(DRIVER_HOME_TIMEZONE, now);
    expect(bounds.date).toBe('2026-07-29');
    expect(bounds.startUtc.toISOString()).toBe('2026-07-28T21:00:00.000Z');
    expect(bounds.endUtc.toISOString()).toBe('2026-07-29T21:00:00.000Z');
  });

  it('keeps same Amman date before local midnight', () => {
    const now = new Date('2026-07-28T20:59:00.000Z'); // 23:59 Amman
    const bounds = calendarDayBoundsInTimeZone(DRIVER_HOME_TIMEZONE, now);
    expect(bounds.date).toBe('2026-07-28');
  });
});
```

- [ ] **Step 2: Run — expect FAIL**

```bash
npm test -- --testPathPatterns=driver-day-bounds.spec --no-coverage
```

Working directory: `rideshare-backend`  
Expected: FAIL (module missing)

- [ ] **Step 3: Implement helper**

Use `Intl.DateTimeFormat` with `timeZone` + `en-CA` for `YYYY-MM-DD`, then resolve local midnight to UTC by constructing the offset via a formatter that includes `timeZoneName` **or** binary-search / iterative offset:

```ts
export const DRIVER_HOME_TIMEZONE = 'Asia/Amman';

export type DayBounds = {
  startUtc: Date;
  endUtc: Date;
  date: string;
};

function ymdInTimeZone(timeZone: string, date: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

/** UTC instant for local `YYYY-MM-DD` 00:00:00 in [timeZone]. */
function localMidnightUtc(timeZone: string, ymd: string): Date {
  // Probe: guess UTC = ymd noon Z, read local parts, adjust.
  const [y, m, d] = ymd.split('-').map(Number);
  let guess = Date.UTC(y, m - 1, d, 0, 0, 0);
  for (let i = 0; i < 3; i++) {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date(guess));
    const get = (type: string) =>
      Number(parts.find((p) => p.type === type)?.value);
    const asUtc = Date.UTC(
      get('year'),
      get('month') - 1,
      get('day'),
      get('hour'),
      get('minute'),
      get('second'),
    );
    guess += Date.UTC(y, m - 1, d, 0, 0, 0) - asUtc;
  }
  return new Date(guess);
}

export function calendarDayBoundsInTimeZone(
  timeZone: string,
  now: Date = new Date(),
): DayBounds {
  const date = ymdInTimeZone(timeZone, now);
  const startUtc = localMidnightUtc(timeZone, date);
  const endUtc = new Date(startUtc.getTime() + 24 * 60 * 60 * 1000);
  // If DST made the day ≠ 24h, re-derive end from next local YMD:
  const nextYmd = ymdInTimeZone(
    timeZone,
    new Date(startUtc.getTime() + 36 * 60 * 60 * 1000),
  );
  const endFromNext = localMidnightUtc(timeZone, nextYmd);
  return { startUtc, endUtc: endFromNext, date };
}
```

Adjust the midnight algorithm if tests fail on Windows ICU — keep tests as source of truth.

- [ ] **Step 4: Re-run — expect PASS**

```bash
npm test -- --testPathPatterns=driver-day-bounds.spec --no-coverage
```

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare-backend/src/modules/trips/driver-day-bounds.ts rideshare-backend/src/modules/trips/driver-day-bounds.spec.ts
git commit -m "feat: add Asia/Amman calendar day bounds helper"
```

---

### Task 2: `GET /trips/my/daily-summary`

**Files:**
- Modify: `rideshare-backend/src/modules/trips/trips.module.ts`
- Modify: `rideshare-backend/src/modules/trips/trips.service.ts`
- Modify: `rideshare-backend/src/modules/trips/trips.controller.ts`
- Modify: `rideshare-backend/src/modules/trips/trips.service.spec.ts`

**Interfaces:**
- Consumes: `calendarDayBoundsInTimeZone`, `TripEntity`, `BookingEntity`, `BookingStatus`, `TripStatus`
- Produces:

```ts
async getDailySummary(driverId: string, now?: Date): Promise<{
  newRequests: number;
  todayTrips: number;
  todayBookings: number;
  timezone: string;
  date: string;
}>;
```

- [ ] **Step 1: Register `BookingEntity` on TripsModule**

```ts
import { BookingEntity } from '../../database/entities/booking.entity';

TypeOrmModule.forFeature([
  TripEntity,
  DriverAvailabilityEntity,
  BookingEntity,
]),
```

Inject in `TripsService`:

```ts
@InjectRepository(BookingEntity)
private bookingRepo: Repository<BookingEntity>,
```

- [ ] **Step 2: Write failing service tests**

Add to `trips.service.spec.ts` (extend `beforeEach` providers with `BookingEntity` repo mock + queues already present):

```ts
describe('getDailySummary', () => {
  it('counts pending requests, today trips, and today bookings', async () => {
    const now = new Date('2026-07-28T10:00:00.000Z'); // 13:00 Amman
    tripRepo.createQueryBuilder = jest.fn().mockReturnValue({
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn().mockResolvedValue(1),
    });
    bookingRepo.createQueryBuilder = jest
      .fn()
      .mockReturnValueOnce({
        // newRequests
        innerJoin: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getCount: jest.fn().mockResolvedValue(2),
      })
      .mockReturnValueOnce({
        // todayBookings
        innerJoin: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getCount: jest.fn().mockResolvedValue(5),
      });

    const summary = await service.getDailySummary(DRIVER_ID, now);
    expect(summary).toEqual({
      newRequests: 2,
      todayTrips: 1,
      todayBookings: 5,
      timezone: 'Asia/Amman',
      date: '2026-07-28',
    });
  });
});
```

Wire `bookingRepo` in the testing module the same way as `tripRepo`.

- [ ] **Step 3: Run — expect FAIL**

```bash
npm test -- --testPathPatterns=trips.service.spec --no-coverage
```

Expected: FAIL (`getDailySummary` missing)

- [ ] **Step 4: Implement `getDailySummary`**

```ts
async getDailySummary(driverId: string, now: Date = new Date()) {
  const { startUtc, endUtc, date } = calendarDayBoundsInTimeZone(
    DRIVER_HOME_TIMEZONE,
    now,
  );

  const newRequests = await this.bookingRepo
    .createQueryBuilder('b')
    .innerJoin(TripEntity, 't', 't.id = b.tripId')
    .where('t.driverId = :driverId', { driverId })
    .andWhere('b.status = :pending', { pending: BookingStatus.PENDING })
    .getCount();

  const todayTrips = await this.tripRepo
    .createQueryBuilder('t')
    .where('t.driverId = :driverId', { driverId })
    .andWhere('t.status != :cancelled', {
      cancelled: TripStatus.CANCELLED,
    })
    .andWhere('t.departureTime >= :start', { start: startUtc })
    .andWhere('t.departureTime < :end', { end: endUtc })
    .getCount();

  const todayBookings = await this.bookingRepo
    .createQueryBuilder('b')
    .innerJoin(TripEntity, 't', 't.id = b.tripId')
    .where('t.driverId = :driverId', { driverId })
    .andWhere('t.status != :cancelled', {
      cancelled: TripStatus.CANCELLED,
    })
    .andWhere('t.departureTime >= :start', { start: startUtc })
    .andWhere('t.departureTime < :end', { end: endUtc })
    .andWhere('b.status != :bCancelled', {
      bCancelled: BookingStatus.CANCELLED,
    })
    .getCount();

  return {
    newRequests,
    todayTrips,
    todayBookings,
    timezone: DRIVER_HOME_TIMEZONE,
    date,
  };
}
```

Import `BookingEntity`, `BookingStatus`, `DRIVER_HOME_TIMEZONE`, `calendarDayBoundsInTimeZone`.

- [ ] **Step 5: Add controller route (before `@Get(':id')`)**

```ts
  @Get('my/daily-summary')
  @UseGuards(RolesGuard)
  @Roles('driver')
  @ApiOperation({ summary: 'Driver home daily summary counters' })
  @ApiResponse({ status: 200, description: 'Daily summary' })
  async getMyDailySummary(@CurrentUser('id') driverId: string) {
    return this.tripsService.getDailySummary(driverId);
  }
```

Place it immediately after `getMyTrips` / before any `:id` route.

- [ ] **Step 6: Re-run — expect PASS**

```bash
npm test -- --testPathPatterns=trips.service.spec --no-coverage
npm test -- --testPathPatterns=driver-day-bounds.spec --no-coverage
```

- [ ] **Step 7: Commit (only if user requested)**

```bash
git add rideshare-backend/src/modules/trips
git commit -m "feat: add driver daily-summary endpoint for home stats"
```

---

### Task 3: Mobile summary client

**Files:**
- Create: `rideshare/lib/models/driver_daily_summary.dart`
- Modify: `rideshare/lib/core/api/api_endpoints.dart`
- Modify: `rideshare/lib/core/services/trip_service.dart`
- Modify: `rideshare/lib/providers/trip_provider.dart`

**Interfaces:**
- Produces:

```dart
class DriverDailySummary {
  final int newRequests;
  final int todayTrips;
  final int todayBookings;
  final String timezone;
  final String date;

  factory DriverDailySummary.fromJson(Map<String, dynamic> json);
  static DriverDailySummary empty();
}

// TripService
Future<DriverDailySummary> getDriverDailySummary();

// TripProvider
DriverDailySummary? get dailySummary;
bool get isDailySummaryLoading;
String? get dailySummaryError;
Future<void> fetchDriverDailySummary();
```

- [ ] **Step 1: Model + endpoint**

`api_endpoints.dart`:

```dart
static const String myTripsDailySummary = '/trips/my/daily-summary';
```

`driver_daily_summary.dart`:

```dart
class DriverDailySummary {
  const DriverDailySummary({
    required this.newRequests,
    required this.todayTrips,
    required this.todayBookings,
    required this.timezone,
    required this.date,
  });

  final int newRequests;
  final int todayTrips;
  final int todayBookings;
  final String timezone;
  final String date;

  factory DriverDailySummary.empty() => const DriverDailySummary(
        newRequests: 0,
        todayTrips: 0,
        todayBookings: 0,
        timezone: 'Asia/Amman',
        date: '',
      );

  factory DriverDailySummary.fromJson(Map<String, dynamic> json) {
    return DriverDailySummary(
      newRequests: (json['newRequests'] as num?)?.toInt() ?? 0,
      todayTrips: (json['todayTrips'] as num?)?.toInt() ?? 0,
      todayBookings: (json['todayBookings'] as num?)?.toInt() ?? 0,
      timezone: json['timezone'] as String? ?? 'Asia/Amman',
      date: json['date'] as String? ?? '',
    );
  }
}
```

- [ ] **Step 2: TripService method**

Follow existing Dio patterns in `getDriverTrips`:

```dart
Future<DriverDailySummary> getDriverDailySummary() async {
  final response = await _dio.get(ApiEndpoints.myTripsDailySummary);
  final data = response.data;
  if (data is Map<String, dynamic>) {
    return DriverDailySummary.fromJson(data);
  }
  if (data is Map) {
    return DriverDailySummary.fromJson(Map<String, dynamic>.from(data));
  }
  return DriverDailySummary.empty();
}
```

(Adapt `_dio` / `ApiClient` name to whatever `TripService` already uses.)

- [ ] **Step 3: TripProvider cache**

```dart
DriverDailySummary? _dailySummary;
bool _dailySummaryLoading = false;
String? _dailySummaryError;

DriverDailySummary? get dailySummary => _dailySummary;
bool get isDailySummaryLoading => _dailySummaryLoading;
String? get dailySummaryError => _dailySummaryError;

Future<void> fetchDriverDailySummary() async {
  _dailySummaryLoading = true;
  _dailySummaryError = null;
  notifyListeners();
  try {
    _dailySummary = await _tripService.getDriverDailySummary();
  } catch (e) {
    _dailySummaryError = e.toString();
  } finally {
    _dailySummaryLoading = false;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Analyze**

```bash
dart analyze lib/models/driver_daily_summary.dart lib/core/services/trip_service.dart lib/providers/trip_provider.dart
```

Expected: no errors

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare/lib/models/driver_daily_summary.dart rideshare/lib/core/api/api_endpoints.dart rideshare/lib/core/services/trip_service.dart rideshare/lib/providers/trip_provider.dart
git commit -m "feat: fetch driver daily summary on mobile"
```

---

### Task 4: l10n strings

**Files:**
- Modify: `rideshare/lib/l10n/app_ar.arb`
- Modify: `rideshare/lib/l10n/app_en.arb`
- Run: `flutter gen-l10n`

- [ ] **Step 1: Add keys**

Arabic:

```json
"driverHomeGreeting": "مرحبًا {name}",
"@driverHomeGreeting": { "placeholders": { "name": { "type": "String" } } },
"driverHomeReadySubtitle": "جاهز لاستقبال الركاب؟",
"driverHomeReadyHint": "قم بنشر رحلة أو اتصل لاستقبال طلبات مباشرة.",
"driverAvailabilityStatusLabel": "الحالة",
"driverAvailabilityOnline": "متصل",
"driverAvailabilityOffline": "غير متصل",
"driverAvailabilityOnlineHint": "ستستقبل طلبات مباشرة",
"driverAvailabilityOfflineHint": "لن تستقبل طلبات مباشرة",
"driverAvailabilityActivateBanner": "قم بالتفعيل لتظهر رحلاتك المباشرة للركاب في منطقتك",
"publishSharedTripTitle": "انشر رحلة مشتركة جديدة",
"publishSharedTripSubtitle": "حدّد مسارك وتفاصيل رحلتك واستقبل حجوزات الركاب",
"locationLastUpdatedJustNow": "آخر تحديث الآن",
"locationLastUpdatedMinutes": "آخر تحديث قبل {minutes} د",
"@locationLastUpdatedMinutes": { "placeholders": { "minutes": { "type": "int" } } },
"viewOnMap": "عرض على الخريطة",
"updateLocation": "تحديث الموقع",
"dailySummaryTitle": "ملخص اليوم",
"dailySummaryNewRequests": "طلبات جديدة",
"dailySummaryNewRequestsHint": "تحتاج إلى رد",
"dailySummaryTodayTrips": "رحلات اليوم",
"dailySummaryTodayTripsHint": "رحلة منشورة",
"dailySummaryBookings": "الحجوزات",
"dailySummaryBookingsHint": "إجمالي الحجوزات",
"viewAllStatistics": "عرض جميع الإحصائيات",
"currentTripsTitle": "رحلاتك الحالية",
"viewAll": "عرض الكل",
"noPublishedTripsTitle": "لا توجد رحلات منشورة",
"noPublishedTripsSubtitle": "قم بإنشاء ونشر رحلتك الأولى ليبدأ الركاب بالحجز.",
"publishTripNow": "انشر رحلة الآن",
"dailySummaryRetry": "إعادة المحاولة"
```

English: matching keys with clear English copy.

- [ ] **Step 2: Generate**

```bash
flutter gen-l10n
```

Working directory: `rideshare`  
Expected: generated getters exist

- [ ] **Step 3: Commit (only if user requested)**

```bash
git add rideshare/lib/l10n
git commit -m "chore: add driver home redesign l10n"
```

---

### Task 5: Section widgets + orchestrator

**Files:**
- Create widgets listed in file map
- Modify: `rideshare/lib/screens/home/tabs/driver_home_content.dart`
- Modify: `rideshare/lib/screens/home/widgets/driver_availability_card.dart` (UI only)

**Interfaces:**
- Consumes: `UserModel`, location callbacks, `TripProvider`, `RouteNames.createTrip`, `RouteNames.myTrips`
- Produces: mockup-ordered scroll; pull-to-refresh fetches trips **and** daily summary

- [ ] **Step 1: `DriverHomeHeader`**

Props: `user`, `onOpenDrawer`. Layout: avatar (tap → drawer) + greeting/`driverHomeReadySubtitle`/`driverHomeReadyHint` + `NotificationIconButton`. No menu icon.

- [ ] **Step 2: Restyle `DriverAvailabilityCard`**

Keep all InstantRide logic. UI: status label + online/offline text + toggle + offline info banner (`driverAvailabilityActivateBanner`). Optional car/wifi Iconsax decoration. Do not change timers/API calls.

- [ ] **Step 3: `DriverPublishTripCta`**

Primary teal card → `Navigator.pushNamed(context, RouteNames.createTrip)`.

- [ ] **Step 4: `DriverLocationCard`**

Show `userLocation?.name`, loading state, `onChangeLocation` (map), `onRefreshLocation`. Optional `lastUpdatedAt` if parent passes a `DateTime?`; otherwise hide relative time.

Extend `DriverHomeContent` constructor with optional `DateTime? locationUpdatedAt` only if `HomeScreen` already tracks it; otherwise omit the relative line (do not invent fake timestamps).

- [ ] **Step 5: `DriverDailySummaryCard`**

Read `TripProvider` summary fields. Three compact cards + `viewAllStatistics` → `RouteNames.myTrips`. Loading: small progress or placeholders. Error: text + `dailySummaryRetry` calling `fetchDriverDailySummary`.

- [ ] **Step 6: `DriverCurrentTripsSection`**

Move stream/filter logic from current `_buildMyTripsSection`. Header with `viewAll` → `RouteNames.myTrips`. Empty: title/subtitle/CTA per new l10n. List: existing `TripCard` (max 5).

- [ ] **Step 7: Rewrite `DriverHomeContent` body**

```dart
slivers: [
  SliverToBoxAdapter(child: DriverHomeHeader(...)),
  const SliverToBoxAdapter(child: DriverAvailabilityCard()),
  SliverToBoxAdapter(child: DriverPublishTripCta()),
  ...
]
```

In first frame + `_handleRefresh`:

```dart
await Future.wait([
  context.read<TripProvider>().fetchDriverTrips(...),
  context.read<TripProvider>().fetchDriverDailySummary(),
  if (widget.onRefreshData != null) widget.onRefreshData!(),
]);
```

- [ ] **Step 8: Analyze**

```bash
dart analyze lib/screens/home/tabs/driver_home_content.dart lib/screens/home/widgets
```

Expected: no errors

- [ ] **Step 9: Commit (only if user requested)**

```bash
git add rideshare/lib/screens/home
git commit -m "feat: redesign driver home to match mockup sections"
```

---

### Task 6: Verification

- [ ] **Step 1: Backend tests**

```bash
npm test -- --testPathPatterns=driver-day-bounds.spec --no-coverage
npm test -- --testPathPatterns=trips.service.spec --no-coverage
```

Expected: PASS

- [ ] **Step 2: Flutter analyze**

```bash
dart analyze lib/screens/home lib/models/driver_daily_summary.dart lib/providers/trip_provider.dart lib/core/services/trip_service.dart
```

Expected: no issues in touched paths

- [ ] **Step 3: Manual checklist**

1. Driver home matches mockup order (header → availability → CTA → location → summary → trips).
2. Offline banner + toggle still works (instant offers).
3. Summary numbers load from API; retry works on failure.
4. Empty trips CTA opens create-trip wizard.
5. Avatar opens drawer; bell opens notifications.
6. RTL layout looks correct.

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Section widget split | 5 |
| Availability restyle, same APIs | 5 |
| Publish CTA / location / current trips | 5 |
| Daily summary endpoint + definitions | 1–2 |
| Mobile client + cache | 3 |
| l10n | 4 |
| Avatar → drawer, no hamburger | 5 |
| Bottom nav unchanged | (no change) |
| No mockup PNG crops | 5 |
| Tests + manual | 1, 2, 6 |

## Out of scope

- Passenger home / bottom nav redesign
- Historical analytics screen
- Instant-ride protocol changes
- Create-trip wizard changes
