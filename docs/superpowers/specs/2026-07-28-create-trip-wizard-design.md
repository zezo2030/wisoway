# Create Trip Wizard — Design Spec

**Date:** 2026-07-28  
**Status:** Approved (progressive cabin option B locked 2026-07-28)  
**Approach:** Measured restructure (3-step wizard + shared state)  
**Assets inventory:** `docs/superpowers/assets/2026-07-28-create-trip-wizard/`

## Goal

Replace the single long `CreateTripScreen` form with a 3-step wizard matching the provided mockups, lock seat **layout shape** to the driver's vehicle type (no row editing during trip creation), allow available seat **count** within that layout max, and add per-trip **prevent gender mixing** with a real **family booking** exception in booking logic.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | Full 3-step wizard (route → details → review) |
| Seat counter | Increase/decrease within `1..maxLayoutSeats` |
| Prevent mixing | Per-trip toggle; default from vehicle settings |
| Sedan catalog | 4 passenger seats; layout `[1, 3]` |
| Family exception | Real booking-logic exemption (`isFamilyBooking`) |
| Architecture | Split steps + shared state inside create-trip flow |
| Save as draft | Out of scope (hide or disable) |
| Custom car PNGs | Prefer CustomPainter / widgets; Iconsax for chrome |

## Current context

- `rideshare/lib/screens/driver/create_trip_screen.dart` is one scrollable form (~1400 lines), not a stepper wizard.
- Seat layout + `preventGenderMixing` live on the vehicle (`VehicleSettingsScreen`) and are copied onto the trip at create time via backend `TripsService.resolveVehicleSeatLayout`.
- Vehicle type templates live in `rideshare-backend/src/modules/vehicles/vehicle-types.ts`.
- Gender adjacency is enforced in `bookings.service.ts` + `gender-adjacency.ts` when `trip.seatLayout.preventGenderMixing` is true. There is no family-booking flag today.

## Architecture

```
CreateTripScreen (shell: app bar, stepper, prev/next/publish)
├── CreateTripWizardState (shared fields + validation helpers)
├── Step1Route
├── Step2Details
└── Step3Review
```

Supporting pieces:

- `VehicleSeatLayoutPicker` — top-down seat UI from layout config + available count.
- Backend catalog update for sedan.
- Booking DTO/service: `isFamilyBooking` skips gender checks when true.

### Data flow

1. On open: load driver vehicle + vehicle-type catalog.
2. Base layout = `vehicle.seatLayout` if present, else template for `vehicle.vehicleType`.
3. `availableSeatCount` initializes to `maxLayoutSeats` (passenger seats only; driver not counted).
4. `preventGenderMixing` initializes from vehicle layout; editable for this trip only.
5. Publish does **not** mutate vehicle settings.
6. **API extension (required):** `CreateTripDto` today always copies layout from the vehicle and ignores client seat-count / mixing overrides. Extend it with optional:
   - `availableSeats?: number` — clamp to `1..maxLayoutSeats`; generate that many passenger seats from the layout order (remaining layout slots are not published).
   - `preventGenderMixing?: boolean` — if provided, override the flag on the trip’s stored `seatLayout` only; layout rows/shape still come from the vehicle/template.

## Step 1 — Route (المسار)

- From / to fields + optional stops (max 5) — keep existing location picker behavior.
- Map / distance / duration / road-type summary when data exists; omit quietly if not.
- Next enabled only when from + to are valid.

## Step 2 — Details (تفاصيل الرحلة)

- Date + departure time side by side.
- Visual seat layout from vehicle type / saved layout (no rows/seats-per-row editors).
- `+/-` adjusts `availableSeatCount` in `1..maxLayoutSeats`.
- Price per seat (JOD), passenger notes, recurrence — preserve current behavior.
- **Prevent gender mixing** card:
  - Toggle
  - Always-visible note: family bookings are exempt; option can be disabled to allow mixing
- Next requires: departure time, valid price, `availableSeatCount >= 1`.

### Cabin preview — progressive length (locked 2026-07-28)

**Choice:** Option B — car shell height follows **rows in use** for the current
`availableSeatCount`, not the full vehicle-type max at all times.

Rules:

1. **Fill order:** passenger seats fill front → back in layout row order
   (`seatsPerRowList` / catalog template). Driver placeholder is UI-only,
   always shown in row 0, never counted.
2. **Visible rows:** only rows that contain at least one selected (green)
   passenger seat are drawn. Later empty rows are **omitted** (not shown as
   inactive inside a full-length shell).
3. **Partial last row:** if the selected count ends mid-row, remaining slots
   in that visible row render as **inactive** (white outline).
4. **Shell length:** cabin height animates (~250ms) as rows appear/disappear
   when `+/-` changes the count. Width stays typical for a top-down car.
5. **Max still from vehicle type:** `+/-` clamps to `1..maxLayoutSeats`;
   shape never invents seats beyond the catalog/template layout.
6. **Graphics:** `CustomPainter` white car shell (mirrors, front/rear glass) +
   seat widgets. No cropped mockup PNGs (poor quality). Full-screen mockups
   remain design references only.

Examples:

| Count | Sedan `[1, 3]` | Visual |
|------:|----------------|--------|
| 1 | Front passenger only | Short cabin: driver + 1 green |
| 2 | Front + 1 rear | Longer: rear row appears; 2 rear slots inactive |
| 4 | Full layout | Full sedan length; all passenger seats green |

| Count | Van `[2, 3, 2]` | Visual |
|------:|-----------------|--------|
| 2 | Row 0 only | Short |
| 5 | Rows 0–1 | Medium |
| 7 | All three rows | Long |

### Sedan catalog change

Update `VEHICLE_TYPE_CATALOG.sedan`:

```ts
{
  type: 'sedan',
  label: { en: 'Sedan', ar: 'سيدان' },
  seats: 4,
  layout: {
    rows: 2,
    seatsPerRow: 3,
    seatsPerRowList: [1, 3],
    preventGenderMixing: false,
  },
}
```

Existing vehicles keep stored `seatLayout`. New sedan selection / missing layout uses the new template.

## Step 3 — Review & publish (مراجعة ونشر)

- Cards: route summary, extra details (recurrence + prevent mixing), vehicle, passenger notes.
- Publish info banner (shield copy).
- Back to edit → step 2 (stepper may jump only to completed steps).
- Publish → existing create-trip success path (trip management / my trips).
- Draft save: out of scope.

## Family booking exception

### Product rule

When a passenger marks a booking as a **family booking**, gender-mixing / gender-adjacency rules are **not** applied for that booking, even if the trip has `preventGenderMixing: true`.

### Technical shape

- Add `isFamilyBooking: boolean` (default `false`) to multi-seat booking DTO (and persist on booking if the schema supports a column/JSON field; otherwise store on booking metadata consistently with existing patterns).
- Passenger UI: show “family booking” only when booking **2+ seats**.
- Validation: `isFamilyBooking: true` with a single seat → `400` validation error.
- In `createMultiSeat` (and any path that runs gender adjacency / adjacent-gender checks): if `isFamilyBooking`, skip those checks for this request.
- Non-family bookings keep current prevent-mixing behavior.

## Error handling

| Case | Behavior |
|------|----------|
| No vehicle / no resolvable layout | Message + link to vehicle settings; block publish |
| Vehicle load failure | Retry; fall back to type template if possible |
| Publish failure | Existing `ErrorSurface`; remain on step 3 |
| Family flag with one seat | API validation error |
| Mixing on + non-family conflict | Reject as today |

## Testing

- Unit: sedan template = 4 seats and `[1, 3]`; counter clamps to max; trip gets per-trip `preventGenderMixing`.
- Unit: progressive cabin — given layout + count, returns visible row slice and per-seat available/inactive flags (e.g. sedan count 2 → 2 rows, rear has 1 green + 2 inactive).
- Unit/service: `isFamilyBooking` bypasses gender checks; without it, conflicts still fail.
- Smoke/widget: step navigation + step-2/3 validation gates; +/- changes cabin height.

## File touch list (indicative)

**Mobile**

- `rideshare/lib/screens/driver/create_trip_screen.dart` (shell / orchestration)
- New step widgets under `rideshare/lib/screens/driver/create_trip/` (or similar)
- New seat layout picker widget
- Booking UI: family toggle when selecting multiple seats
- `app_ar.arb` / `app_en.arb` strings

**Backend**

- `vehicle-types.ts` sedan template
- `create-trip.dto.ts` + `trips.service.ts`: optional `availableSeats` + `preventGenderMixing` overrides
- Bookings DTO + `bookings.service.ts` family bypass
- Tests: vehicle types / create-trip overrides / gender adjacency / bookings

## Out of scope

- Save as draft
- Editing seat rows during trip creation
- Shipping cropped PNG car/icons from mockups (use Iconsax + CustomPainter)
- Per-vehicle-type PNG car shells (one scalable painter)
- Changing vehicle-settings UX beyond what catalog/default layout requires
- Redesigning passenger browse/trip cards except showing prevent-mixing / family where needed for the exception

## Assets

Reference mockups and icon/asset inventory:

- `docs/superpowers/assets/2026-07-28-create-trip-wizard/step1-route.png`
- `docs/superpowers/assets/2026-07-28-create-trip-wizard/step2-details.png`
- `docs/superpowers/assets/2026-07-28-create-trip-wizard/step3-review.png`
- `docs/superpowers/assets/2026-07-28-create-trip-wizard/ASSETS_INVENTORY.md`
