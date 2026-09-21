# Create Trip Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a 3-step create-trip wizard with vehicle-type seat layouts, per-trip prevent-gender-mixing, and a real family-booking exemption.

**Architecture:** Split `CreateTripScreen` into shell + three step widgets sharing wizard state. Extend create-trip API with optional `availableSeats` / `preventGenderMixing`. Update sedan catalog to 4 seats `[1,3]`. Add `isFamilyBooking` on multi-seat bookings to skip gender adjacency.

**Tech Stack:** NestJS 11 / TypeORM / Jest (backend); Flutter 3.9 / Dart 3 / Provider / Iconsax (mobile)

**Spec:** `docs/superpowers/specs/2026-07-28-create-trip-wizard-design.md`  
**Assets:** `docs/superpowers/assets/2026-07-28-create-trip-wizard/`  
**Follow-up (progressive cabin option B):** `docs/superpowers/plans/2026-07-28-progressive-cabin-seat-picker.md`

## Global Constraints

- No row/seats-per-row editors during trip creation
- Seat counter clamped to `1..maxLayoutSeats` from vehicle layout / type template
- Per-trip `preventGenderMixing` must not mutate vehicle settings
- Sedan catalog: `seats: 4`, `seatsPerRowList: [1, 3]`
- Family exception only when `isFamilyBooking === true` and seat count ≥ 2
- Save-as-draft out of scope (hide/disable)
- Prefer Iconsax + CustomPainter; no cropped mockup PNGs as production icons
- Follow existing Arabic/English ARB + generated l10n pattern
- Do not commit unless the user explicitly asks (agent may stage mentally; leave commit steps as optional for human)

---

## File map

| File | Responsibility |
|------|----------------|
| `rideshare-backend/src/modules/vehicles/vehicle-types.ts` | Sedan template update |
| `rideshare-backend/test/unit/vehicle-types.resolver.spec.ts` | Catalog assertions |
| `rideshare-backend/src/modules/trips/dto/create-trip.dto.ts` | Optional overrides |
| `rideshare-backend/src/modules/trips/trips.service.ts` | Apply overrides when creating trip |
| `rideshare-backend/src/modules/trips/trips.service.spec.ts` | Override tests |
| `rideshare-backend/src/database/entities/booking.entity.ts` | `isFamilyBooking` column |
| New migration under `rideshare-backend/src/database/migrations/` | Add column |
| `rideshare-backend/src/modules/bookings/dto/create-multi-seat-booking.dto.ts` | DTO field + validation |
| `rideshare-backend/src/modules/bookings/bookings.service.ts` | Skip gender checks when family |
| `rideshare-backend/src/modules/bookings/bookings.service.spec.ts` | Family bypass tests |
| `rideshare/lib/screens/driver/create_trip/create_trip_wizard_state.dart` | Shared wizard state |
| `rideshare/lib/screens/driver/create_trip/create_trip_stepper.dart` | Stepper chrome |
| `rideshare/lib/screens/driver/create_trip/step1_route.dart` | Route step UI |
| `rideshare/lib/screens/driver/create_trip/step2_details.dart` | Details step UI |
| `rideshare/lib/screens/driver/create_trip/step3_review.dart` | Review step UI |
| `rideshare/lib/widgets/vehicle_seat_layout_picker.dart` | Top-down seat picker |
| `rideshare/lib/screens/driver/create_trip_screen.dart` | Shell orchestration |
| `rideshare/lib/core/services/trip_service.dart` | Send overrides |
| `rideshare/lib/providers/trip_provider.dart` | Pass overrides |
| `rideshare/lib/core/services/booking_service.dart` | Send `isFamilyBooking` |
| `rideshare/lib/screens/passenger/companion_picker_screen.dart` | Family toggle UI |
| `rideshare/lib/l10n/app_ar.arb` + `app_en.arb` | New strings |
| `rideshare/lib/screens/auth/driver_complete_profile_screen.dart` | Sedan fallback seats `4` |

---

### Task 1: Sedan catalog = 4 seats `[1, 3]`

**Files:**
- Modify: `rideshare-backend/src/modules/vehicles/vehicle-types.ts`
- Modify: `rideshare-backend/test/unit/vehicle-types.resolver.spec.ts`
- Modify: `rideshare/lib/screens/auth/driver_complete_profile_screen.dart` (`_fallbackSeatsByType['sedan']`)

**Interfaces:**
- Consumes: `VEHICLE_TYPE_CATALOG`, `countSeatsInLayout`, `resolveVehicleTypeTemplate`
- Produces: sedan template with `seats: 4` and `layout.seatsPerRowList: [1, 3]`

- [x] **Step 1: Update failing expectation in unit test**

In `vehicle-types.resolver.spec.ts`, change the unknown-type fallback assertion from `seats` `3` to `4`:

```ts
expect(template.seats).toBe(4);
```

Add an explicit sedan shape test:

```ts
it('sedan uses 4 passenger seats in [1, 3] layout', () => {
  const template = resolveVehicleTypeTemplate('sedan');
  expect(template.seats).toBe(4);
  expect(template.layout.seatsPerRowList).toEqual([1, 3]);
  expect(countSeatsInLayout(template.layout)).toBe(4);
});
```

- [x] **Step 2: Run test — expect FAIL on seats / list**

Run: `npm test -- --testPathPatterns=vehicle-types.resolver.spec --no-coverage`  
Working directory: `rideshare-backend`  
Expected: FAIL (catalog still has sedan seats 3 / no `[1,3]`)

- [x] **Step 3: Update catalog + Flutter fallback**

In `vehicle-types.ts` set:

```ts
sedan: {
  type: 'sedan',
  label: { en: 'Sedan', ar: 'سيدان' },
  seats: 4,
  layout: {
    rows: 2,
    seatsPerRow: 3,
    seatsPerRowList: [1, 3],
    preventGenderMixing: false,
  },
},
```

In `driver_complete_profile_screen.dart`:

```dart
'sedan': 4,
```

- [x] **Step 4: Re-run unit test — expect PASS**

Run: `npm test -- --testPathPatterns=vehicle-types.resolver.spec --no-coverage`  
Expected: PASS

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare-backend/src/modules/vehicles/vehicle-types.ts rideshare-backend/test/unit/vehicle-types.resolver.spec.ts rideshare/lib/screens/auth/driver_complete_profile_screen.dart
git commit -m "fix: set sedan vehicle template to 4 seats [1,3]"
```

---

### Task 2: Create-trip overrides (`availableSeats`, `preventGenderMixing`)

**Files:**
- Modify: `rideshare-backend/src/modules/trips/dto/create-trip.dto.ts`
- Modify: `rideshare-backend/src/modules/trips/trips.service.ts` (`create` + helpers)
- Modify: `rideshare-backend/src/modules/trips/trips.service.spec.ts`

**Interfaces:**
- Consumes: `resolveVehicleSeatLayout`, `generateSeatsFromLayout`, `countSeatsInLayout` (import from vehicle-types if needed)
- Produces: trip with `totalSeats` / `availableSeats` = requested count; `seatLayout.preventGenderMixing` overridden when provided

- [x] **Step 1: Write failing service tests**

Add tests that mock a vehicle with layout `{ rows: 2, seatsPerRow: 3, seatsPerRowList: [1, 3], preventGenderMixing: true }` and assert:

1. `availableSeats: 2` → trip has 2 seat objects, `totalSeats === 2`, `availableSeats === 2`
2. `preventGenderMixing: false` → `trip.seatLayout.preventGenderMixing === false` while vehicle stays true
3. `availableSeats: 99` → `BadRequestException` (above max)
4. `availableSeats: 0` → validation/`BadRequestException`

Sketch (adapt to existing spec mocks):

```ts
it('create trip clamps published seats to availableSeats override', async () => {
  // arrange vehicle + dto.availableSeats = 2
  const trip = await service.create(dto, driverId);
  expect(trip.totalSeats).toBe(2);
  expect(trip.availableSeats).toBe(2);
  expect(trip.seats).toHaveLength(2);
});

it('create trip overrides preventGenderMixing without mutating vehicle shape', async () => {
  const trip = await service.create(
    { ...dto, preventGenderMixing: false },
    driverId,
  );
  expect(trip.seatLayout.preventGenderMixing).toBe(false);
  expect(trip.seatLayout.seatsPerRowList).toEqual([1, 3]);
});
```

- [x] **Step 2: Run trips.service.spec — expect FAIL**

Run: `npm test -- --testPathPatterns=trips.service.spec --no-coverage`  
Expected: FAIL (DTO/service do not accept overrides yet)

- [x] **Step 3: Extend DTO**

Append to `CreateTripDto`:

```ts
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  availableSeats?: number;

  @IsOptional()
  @IsBoolean()
  preventGenderMixing?: boolean;
```

Add `IsBoolean` to the class-validator import list.

- [x] **Step 4: Apply overrides in `TripsService.create`**

Replace the block that builds seats with:

```ts
const baseLayout = this.resolveVehicleSeatLayout(vehicle);
const seatLayout = {
  ...baseLayout,
  seatsPerRowList: baseLayout.seatsPerRowList
    ? [...baseLayout.seatsPerRowList]
    : undefined,
  preventGenderMixing:
    createTripDto.preventGenderMixing ??
    baseLayout.preventGenderMixing ??
    false,
};

const fullSeats = this.generateSeatsFromLayout(seatLayout);
const maxSeats = fullSeats.length;
const requested = createTripDto.availableSeats ?? maxSeats;
if (requested < 1 || requested > maxSeats) {
  throw new BadRequestException(
    `availableSeats must be between 1 and ${maxSeats}`,
  );
}
const seats = fullSeats.slice(0, requested);
const totalSeats = seats.length;
```

Keep using `seatLayout` / `totalSeats` / `seats` in `tripRepo.create` and recurrence `templateJson` as today.

- [x] **Step 5: Re-run trips.service.spec — expect PASS**

Run: `npm test -- --testPathPatterns=trips.service.spec --no-coverage`  
Expected: PASS

- [ ] **Step 6: Commit (only if user requested)**

```bash
git add rideshare-backend/src/modules/trips/dto/create-trip.dto.ts rideshare-backend/src/modules/trips/trips.service.ts rideshare-backend/src/modules/trips/trips.service.spec.ts
git commit -m "feat: allow create-trip availableSeats and preventGenderMixing overrides"
```

---

### Task 3: Family booking backend exemption

**Files:**
- Create: `rideshare-backend/src/database/migrations/<timestamp>-add-is-family-booking-to-bookings.ts`
- Modify: `rideshare-backend/src/database/entities/booking.entity.ts`
- Modify: `rideshare-backend/src/modules/bookings/dto/create-multi-seat-booking.dto.ts`
- Modify: `rideshare-backend/src/modules/bookings/bookings.service.ts`
- Modify: `rideshare-backend/src/modules/bookings/bookings.service.spec.ts`

**Interfaces:**
- Consumes: `hasGenderAdjacencyViolation`, `CreateMultiSeatBookingDto`
- Produces: `BookingEntity.isFamilyBooking: boolean`; createMultiSeat skips gender checks when family

- [x] **Step 1: Write failing booking tests**

```ts
it('skips gender adjacency when isFamilyBooking is true', async () => {
  // trip.seatLayout.preventGenderMixing = true
  // seats would violate adjacency for mixed genders
  await expect(
    service.createMultiSeat(
      {
        tripId: trip.id,
        isFamilyBooking: true,
        seats: [
          { seatNumber: '0-0', displayName: 'A', gender: 'male', isMainBooker: true },
          { seatNumber: '0-1', displayName: 'B', gender: 'female', isMainBooker: false },
        ],
      },
      userId,
    ),
  ).resolves.toBeTruthy();
});

it('rejects isFamilyBooking with a single seat', async () => {
  await expect(
    service.createMultiSeat(
      {
        tripId: trip.id,
        isFamilyBooking: true,
        seats: [
          { seatNumber: '0-0', displayName: 'A', gender: 'male', isMainBooker: true },
        ],
      },
      userId,
    ),
  ).rejects.toThrow(BadRequestException);
});
```

Adapt seat numbers to the fixture layout in the existing spec.

- [x] **Step 2: Run bookings.service.spec — expect FAIL**

Run: `npm test -- --testPathPatterns=bookings.service.spec --no-coverage`  
Expected: FAIL

- [x] **Step 3: Migration + entity**

Migration up:

```ts
await queryRunner.query(
  `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS "isFamilyBooking" boolean NOT NULL DEFAULT false`,
);
```

Migration down:

```ts
await queryRunner.query(
  `ALTER TABLE bookings DROP COLUMN IF EXISTS "isFamilyBooking"`,
);
```

Entity field:

```ts
@Column({ type: 'boolean', default: false })
isFamilyBooking: boolean;
```

- [x] **Step 4: DTO + service logic**

On `CreateMultiSeatBookingDto` and `AutoPickBookingDto`:

```ts
  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  isFamilyBooking?: boolean;
```

In `createMultiSeat` after reading dto:

```ts
const isFamilyBooking = dto.isFamilyBooking === true;
if (isFamilyBooking && seatDtos.length < 2) {
  throw new BadRequestException(
    'Family booking requires at least 2 seats',
  );
}
```

Replace gender block:

```ts
if (trip.seatLayout?.preventGenderMixing && !isFamilyBooking) {
  const proposed = seatDtos.map((sd) => ({
    seatNumber: sd.seatNumber,
    gender: sd.gender,
  }));
  if (hasGenderAdjacencyViolation(tripSeats, proposed)) {
    throw new BadRequestException(
      'لا يمكن حجز هذه المقاعد بسبب قواعد الفصل بين الجنسين.',
    );
  }
}
```

When persisting booking, set `isFamilyBooking` on the entity.  
Also pass `isFamilyBooking` through `autoPick` → `createMultiSeat`.

- [x] **Step 5: Re-run bookings.service.spec — expect PASS**

Run: `npm test -- --testPathPatterns=bookings.service.spec --no-coverage`  
Expected: PASS

- [ ] **Step 6: Commit (only if user requested)**

```bash
git add rideshare-backend/src/database/migrations rideshare-backend/src/database/entities/booking.entity.ts rideshare-backend/src/modules/bookings
git commit -m "feat: exempt family bookings from gender mixing rules"
```

---

### Task 4: Localization strings

**Files:**
- Modify: `rideshare/lib/l10n/app_ar.arb`
- Modify: `rideshare/lib/l10n/app_en.arb`
- Regenerate: `flutter gen-l10n` (or project’s existing l10n command)

**Interfaces:**
- Produces string getters used by later UI tasks

- [x] **Step 1: Add AR/EN keys**

Arabic (`app_ar.arb`):

```json
"createTripStepRoute": "المسار",
"createTripStepDetails": "تفاصيل الرحلة",
"createTripStepReview": "مراجعة ونشر",
"createTripWhenAndHow": "متى وكيف؟",
"createTripWhenAndHowSubtitle": "حدد تفاصيل رحلتك ومقاعد الركاب والسعر",
"availableSeatsSection": "المقاعد المتاحة",
"seatLegendAvailable": "متاح",
"seatLegendDriver": "غير متاح (السائق)",
"seatLegendInactive": "مقعد خامل",
"preventGenderMixingHint": "يستثنى من ذلك حجز العائلة. يمكن تعطيل هذا الخيار والسماح بالاختلاط.",
"reviewTripTitle": "مراجعة الرحلة",
"reviewTripSubtitle": "تحقق من تفاصيل رحلتك قبل نشرها للركاب",
"publishTrip": "نشر الرحلة",
"backToEdit": "العودة للتعديل",
"publishTripNotice": "سيتم نشر الرحلة بعد المراجعة وسيتمكن الركاب من الحجز.",
"familyBookingLabel": "حجز عائلة",
"familyBookingHint": "يُستثنى حجز العائلة من قواعد منع الاختلاط على هذه الرحلة."
```

English (`app_en.arb`): matching keys with clear English copy.

- [x] **Step 2: Generate l10n**

Run from `rideshare`: `flutter gen-l10n`  
Expected: generated files include new getters; no missing-key errors for these keys.

- [ ] **Step 3: Commit (only if user requested)**

```bash
git add rideshare/lib/l10n
git commit -m "chore: add create-trip wizard and family booking l10n"
```

---

### Task 5: `VehicleSeatLayoutPicker` widget

**Files:**
- Create: `rideshare/lib/widgets/vehicle_seat_layout_picker.dart`
- Optional test: `rideshare/test/widgets/vehicle_seat_layout_picker_test.dart` (if project already has widget tests; otherwise manual)

**Interfaces:**
- Consumes: `SeatLayoutConfig`, `SeatLayoutHelpers.rowSeatCounts`
- Produces:

```dart
class VehicleSeatLayoutPicker extends StatelessWidget {
  const VehicleSeatLayoutPicker({
    super.key,
    required this.layout,
    required this.availableSeatCount,
    required this.onAvailableSeatCountChanged,
  });

  final SeatLayoutConfig layout;
  final int availableSeatCount;
  final ValueChanged<int> onAvailableSeatCountChanged;
}
```

- [x] **Step 1: Implement picker**

Behavior:
- Compute `maxSeats` from layout (`seatsPerRowList` sum or `rows * seatsPerRow`).
- Draw rows from `SeatLayoutHelpers.rowSeatCounts(layout)`.
- For sedan `[1,3]`: row0 = 1 passenger seat (front); treat a dark “driver” placeholder beside it (UI-only, not in count).
- First `availableSeatCount` passenger seats = available (teal + check); remaining = inactive outline.
- Right side: `+/-` stepper clamped `1..maxSeats` calling `onAvailableSeatCountChanged`.
- Legend: available / driver / inactive using l10n keys from Task 4.

Keep styling aligned with app teal (`T.primary`) and mockups in `docs/superpowers/assets/2026-07-28-create-trip-wizard/step2-details.png`.

- [x] **Step 2: Smoke check**

Run from `rideshare`: `dart analyze lib/widgets/vehicle_seat_layout_picker.dart`  
Expected: no errors

- [ ] **Step 3: Commit (only if user requested)**

```bash
git add rideshare/lib/widgets/vehicle_seat_layout_picker.dart
git commit -m "feat: add vehicle seat layout picker for create-trip"
```

---

### Task 6: Wizard state + stepper shell

**Files:**
- Create: `rideshare/lib/screens/driver/create_trip/create_trip_wizard_state.dart`
- Create: `rideshare/lib/screens/driver/create_trip/create_trip_stepper.dart`
- Modify: `rideshare/lib/screens/driver/create_trip_screen.dart` (begin orchestration; keep publish logic)

**Interfaces:**
- Produces:

```dart
class CreateTripWizardState {
  int stepIndex; // 0..2
  LocationModel? from;
  LocationModel? to;
  List<LocationModel> stops;
  DateTime? departureTime;
  int availableSeatCount;
  SeatLayoutConfig? layout;
  bool preventGenderMixing;
  TextEditingController priceController;
  TextEditingController notesController;
  bool enableRecurrence;
  // ...existing recurrence fields moved here or kept on screen state that owns this object

  int get maxLayoutSeats;
  bool get canGoStep2; // from+to set
  bool get canGoStep3; // time + valid price + seats>=1
}
```

- [x] **Step 1: Create state helper**

Implement `maxLayoutSeats`, `canGoStep2`, `canGoStep3`, `clampAvailableSeats()`, and `initFromVehicle(VehicleModel?, SeatLayoutConfig? template)`.

`initFromVehicle`:
- layout = vehicle.seatLayout ?? template
- availableSeatCount = maxLayoutSeats
- preventGenderMixing = layout?.preventGenderMixing ?? false

- [x] **Step 2: Create stepper widget**

Three labeled steps using `createTripStepRoute` / `Details` / `Review`. Completed steps show check; current teal; future grey. Match mockup RTL.

- [x] **Step 3: Wire shell navigation in `CreateTripScreen`**

- Replace single long form body with `IndexedStack`/`PageView` on `stepIndex`.
- Footer: Step0 Next; Step1 Prev/Next; Step2 Back-to-edit + Publish.
- Move existing `_createTrip` to publish path; temporarily still use old field widgets inside steps if needed — full step UIs in Task 7.

- [x] **Step 4: Analyze**

Run: `dart analyze lib/screens/driver/create_trip_screen.dart lib/screens/driver/create_trip`  
Expected: no errors

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare/lib/screens/driver/create_trip rideshare/lib/screens/driver/create_trip_screen.dart
git commit -m "feat: scaffold create-trip three-step wizard shell"
```

---

### Task 7: Step UIs (route / details / review)

**Files:**
- Create: `rideshare/lib/screens/driver/create_trip/step1_route.dart`
- Create: `rideshare/lib/screens/driver/create_trip/step2_details.dart`
- Create: `rideshare/lib/screens/driver/create_trip/step3_review.dart`
- Modify: `rideshare/lib/screens/driver/create_trip_screen.dart`
- Modify: `rideshare/lib/core/services/trip_service.dart`
- Modify: `rideshare/lib/providers/trip_provider.dart`

**Interfaces:**
- Consumes: `CreateTripWizardState`, `VehicleSeatLayoutPicker`, existing location/recurrence widgets
- Produces: publish payload including `availableSeats` + `preventGenderMixing`

- [x] **Step 1: Extend trip API client**

`TripService.createTrip` / `TripProvider.createTrip` add:

```dart
int? availableSeats,
bool? preventGenderMixing,
```

Body:

```dart
if (availableSeats != null) 'availableSeats': availableSeats,
if (preventGenderMixing != null) 'preventGenderMixing': preventGenderMixing,
```

- [x] **Step 2: Implement Step1Route**

Port from/to/stops UI from current screen. Optional map summary if already available; otherwise omit. Reference `step1-route.png`.

- [x] **Step 3: Implement Step2Details**

- Date/time pickers
- `VehicleSeatLayoutPicker`
- Price field
- Notes + recurrence (existing)
- Prevent-mixing `SwitchListTile` + `preventGenderMixingHint`
- No link required to edit rows; optional “vehicle settings” only if layout missing

- [x] **Step 4: Implement Step3Review**

Cards: route, extras (recurrence + mixing), vehicle summary, notes, shield notice. Buttons: `backToEdit` → step 1 or 2; `publishTrip` → `_createTrip` with overrides.

- [x] **Step 5: Call create with overrides**

```dart
await tripProvider.createTrip(
  // ...existing
  availableSeats: wizard.availableSeatCount,
  preventGenderMixing: wizard.preventGenderMixing,
);
```

- [x] **Step 6: Analyze + manual smoke**

Run: `dart analyze lib/screens/driver/create_trip lib/core/services/trip_service.dart lib/providers/trip_provider.dart`  
Manual: open create trip → walk 3 steps → publish with seats=2 and mixing off.

- [ ] **Step 7: Commit (only if user requested)**

```bash
git add rideshare/lib/screens/driver/create_trip rideshare/lib/screens/driver/create_trip_screen.dart rideshare/lib/core/services/trip_service.dart rideshare/lib/providers/trip_provider.dart
git commit -m "feat: implement create-trip wizard steps and publish overrides"
```

---

### Task 8: Passenger family-booking UI

**Files:**
- Modify: `rideshare/lib/core/services/booking_service.dart`
- Modify: `rideshare/lib/screens/passenger/companion_picker_screen.dart`
- Modify: booking bloc/models if they wrap `createMultiSeat` / `autoPick`

**Interfaces:**
- Consumes: `isFamilyBooking` API field from Task 3
- Produces: passenger can toggle family when selecting 2+ seats

- [x] **Step 1: Extend booking client**

```dart
Future<BookingModel> createMultiSeat({
  required String tripId,
  required List<BookingSeatRequest> seats,
  bool sharePhoneWithDriver = false,
  bool isFamilyBooking = false,
}) async {
  final payload = <String, dynamic>{
    'tripId': tripId,
    'seats': seats.map((s) => s.toJson()).toList(),
    'sharePhoneWithDriver': sharePhoneWithDriver,
    'isFamilyBooking': isFamilyBooking,
  };
  // ...
}
```

Mirror on `autoPick`.

- [x] **Step 2: UI toggle on companion picker**

When `lockedSeatNumbers.length >= 2` (or passenger count ≥ 2) and trip has `preventGenderMixing`, show switch:

- Title: `familyBookingLabel`
- Subtitle: `familyBookingHint`

Pass value into submit → `createMultiSeat` / `autoPick`.

If trip does not prevent mixing, hide the toggle (not needed) or show disabled off — prefer hide.

- [x] **Step 3: Client-side seat validation**

In `SeatValidation` / seat selection path: when user intends family booking, do not block mixed-gender selection ahead of API. If family flag is only chosen on companion picker, ensure companion picker does not pre-filter mixed genders when toggle on.

- [x] **Step 4: Analyze**

Run: `dart analyze lib/core/services/booking_service.dart lib/screens/passenger/companion_picker_screen.dart`  
Expected: no errors

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare/lib/core/services/booking_service.dart rideshare/lib/screens/passenger/companion_picker_screen.dart
git commit -m "feat: add family booking toggle for multi-seat bookings"
```

---

### Task 9: End-to-end verification

**Files:** none (verification only)

- [x] **Step 1: Backend suite for touched areas**

```bash
npm test -- --testPathPatterns="vehicle-types.resolver.spec|trips.service.spec|bookings.service.spec" --no-coverage
```

Working directory: `rideshare-backend`  
Expected: PASS

- [x] **Step 2: Flutter analyze on touched paths**

```bash
dart analyze lib/screens/driver/create_trip lib/widgets/vehicle_seat_layout_picker.dart lib/screens/passenger/companion_picker_screen.dart
```

Working directory: `rideshare`  
Expected: no issues

- [x] **Step 3: Manual checklist**

1. Driver with sedan vehicle: step 2 shows 4 passenger seats + driver grey; no row editors.
2. Reduce seats to 2 → publish → trip has 2 bookable seats.
3. Toggle prevent mixing off → trip.seatLayout.preventGenderMixing false; vehicle settings unchanged.
4. Trip with mixing on: non-family mixed adjacent booking rejected; family booking with 2+ seats accepted.
5. Stepper navigation + validation gates match spec.
6. Draft control absent or disabled.

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| 3-step wizard | 6, 7 |
| Layout from vehicle type; no row edit on create | 5, 7 |
| Counter within max | 5, 2 |
| Sedan 4 / `[1,3]` | 1 |
| Per-trip prevent mixing + hint | 7, 2 |
| Family real exemption | 3, 8 |
| CreateTripDto overrides | 2, 7 |
| Errors / missing vehicle | 7 (reuse existing surfaces) |
| Tests | 1–3, 9 |
| Assets / Iconsax | 5, 7 |
| Draft out of scope | 7 (omit) |

## Placeholder / consistency notes

- `CreateTripWizardState` field names must match Task 7 publish call (`availableSeatCount`, `preventGenderMixing`).
- Backend uses `availableSeats` (API) ↔ Flutter `availableSeats` param.
- Family flag name is consistently `isFamilyBooking` across DTO, entity, and Flutter payload.
