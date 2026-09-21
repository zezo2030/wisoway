# Progressive Cabin Seat Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the create-trip step-2 car cabin grow/shrink by visible rows as `availableSeatCount` changes (spec option B), while keeping layout shape locked to the vehicle type.

**Architecture:** Extract a pure `progressiveCabinRows` helper that maps `(rowCounts, availableSeatCount)` → visible rows with available/inactive flags. Wire `VehicleSeatLayoutPicker` to render only those rows inside an `AnimatedSize` CustomPainter shell. No new PNG assets.

**Tech Stack:** Flutter 3.9 / Dart 3; existing `SeatLayoutConfig`, `SeatLayoutHelpers`, Iconsax, theme `T.*`

**Spec:** `docs/superpowers/specs/2026-07-28-create-trip-wizard-design.md` (§ Cabin preview — progressive length)  
**Parent plan:** `docs/superpowers/plans/2026-07-28-create-trip-wizard.md` (wizard already shipped; this plan replaces full-layout cabin drawing)

## Global Constraints

- No row/seats-per-row editors during trip creation
- Seat counter clamped to `1..maxLayoutSeats` from vehicle layout / type template
- Sedan catalog: `seats: 4`, `seatsPerRowList: [1, 3]`
- Prefer Iconsax + CustomPainter; no cropped mockup PNGs as production icons
- Fill order: passenger seats front → back in layout row order
- Later empty rows omitted (not drawn as inactive in a full shell)
- Partial last visible row: unused slots = inactive outline
- Driver placeholder UI-only in first visible layout row (row index 0), never counted
- Cabin height animates ~250ms when rows appear/disappear
- Do not commit unless the user explicitly asks

---

## File map

| File | Responsibility |
|------|----------------|
| `rideshare/lib/utils/seat_layout_helpers.dart` | Add `progressiveCabinRows` + small view models |
| `rideshare/test/utils/progressive_cabin_rows_test.dart` | Unit tests for row slice + flags |
| `rideshare/lib/widgets/vehicle_seat_layout_picker.dart` | Draw visible rows only; `AnimatedSize` shell |
| `docs/superpowers/assets/2026-07-28-create-trip-wizard/ASSETS_INVENTORY.md` | Already updated for option B — no further change required unless copy drifts |

---

### Task 1: Pure helper `progressiveCabinRows`

**Files:**
- Modify: `rideshare/lib/utils/seat_layout_helpers.dart`
- Create: `rideshare/test/utils/progressive_cabin_rows_test.dart`

**Interfaces:**
- Consumes: `SeatLayoutHelpers.rowSeatCounts` (existing), `List<int> rowCounts`, `int availableSeatCount`
- Produces:

```dart
class ProgressiveCabinSeat {
  const ProgressiveCabinSeat({required this.isAvailable});
  final bool isAvailable;
}

class ProgressiveCabinRow {
  const ProgressiveCabinRow({
    required this.layoutRowIndex,
    required this.showDriver,
    required this.passengerSeats,
  });

  /// Index into the full vehicle `rowCounts` list.
  final int layoutRowIndex;

  /// True only when [layoutRowIndex] == 0.
  final bool showDriver;

  /// Full width of this layout row (including inactive trailing slots).
  final List<ProgressiveCabinSeat> passengerSeats;
}

/// Visible cabin rows for [availableSeatCount], filling front → back.
///
/// Clamps count to `1..max` when max > 0. Returns empty list when
/// [rowCounts] is empty or max seats is 0.
static List<ProgressiveCabinRow> progressiveCabinRows({
  required List<int> rowCounts,
  required int availableSeatCount,
})
```

- [x] **Step 1: Write the failing unit tests**

Create `rideshare/test/utils/progressive_cabin_rows_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/utils/seat_layout_helpers.dart';

void main() {
  group('progressiveCabinRows', () {
    test('sedan count 1 → only front row, one available passenger', () {
      final rows = SeatLayoutHelpers.progressiveCabinRows(
        rowCounts: const [1, 3],
        availableSeatCount: 1,
      );
      expect(rows, hasLength(1));
      expect(rows[0].showDriver, isTrue);
      expect(rows[0].passengerSeats, hasLength(1));
      expect(rows[0].passengerSeats[0].isAvailable, isTrue);
    });

    test('sedan count 2 → two rows; rear has 1 available + 2 inactive', () {
      final rows = SeatLayoutHelpers.progressiveCabinRows(
        rowCounts: const [1, 3],
        availableSeatCount: 2,
      );
      expect(rows, hasLength(2));
      expect(rows[0].passengerSeats.single.isAvailable, isTrue);
      expect(rows[1].showDriver, isFalse);
      expect(
        rows[1].passengerSeats.map((s) => s.isAvailable).toList(),
        [true, false, false],
      );
    });

    test('sedan count 4 → full layout all available', () {
      final rows = SeatLayoutHelpers.progressiveCabinRows(
        rowCounts: const [1, 3],
        availableSeatCount: 4,
      );
      expect(rows, hasLength(2));
      expect(
        rows.expand((r) => r.passengerSeats).every((s) => s.isAvailable),
        isTrue,
      );
    });

    test('van count 5 → two visible rows for [2,3,2]', () {
      final rows = SeatLayoutHelpers.progressiveCabinRows(
        rowCounts: const [2, 3, 2],
        availableSeatCount: 5,
      );
      expect(rows, hasLength(2));
      expect(rows[0].passengerSeats.map((s) => s.isAvailable), [true, true]);
      expect(
        rows[1].passengerSeats.map((s) => s.isAvailable).toList(),
        [true, true, true],
      );
    });

    test('clamps above max and below 1', () {
      final high = SeatLayoutHelpers.progressiveCabinRows(
        rowCounts: const [1, 3],
        availableSeatCount: 99,
      );
      expect(high.expand((r) => r.passengerSeats).length, 4);
      expect(
        high.expand((r) => r.passengerSeats).every((s) => s.isAvailable),
        isTrue,
      );

      final low = SeatLayoutHelpers.progressiveCabinRows(
        rowCounts: const [1, 3],
        availableSeatCount: 0,
      );
      expect(low, hasLength(1));
      expect(low[0].passengerSeats.single.isAvailable, isTrue);
    });

    test('empty rowCounts → empty result', () {
      expect(
        SeatLayoutHelpers.progressiveCabinRows(
          rowCounts: const [],
          availableSeatCount: 3,
        ),
        isEmpty,
      );
    });
  });
}
```

- [x] **Step 2: Run tests — expect FAIL**

Run from `rideshare`:

```bash
flutter test test/utils/progressive_cabin_rows_test.dart
```

Expected: FAIL — `progressiveCabinRows` / types not defined.

- [x] **Step 3: Implement helper**

Append to `rideshare/lib/utils/seat_layout_helpers.dart` (after `SeatLayoutCoords`):

```dart
class ProgressiveCabinSeat {
  const ProgressiveCabinSeat({required this.isAvailable});
  final bool isAvailable;
}

class ProgressiveCabinRow {
  const ProgressiveCabinRow({
    required this.layoutRowIndex,
    required this.showDriver,
    required this.passengerSeats,
  });

  final int layoutRowIndex;
  final bool showDriver;
  final List<ProgressiveCabinSeat> passengerSeats;
}
```

Inside `SeatLayoutHelpers`, add:

```dart
  /// Visible cabin rows for [availableSeatCount], filling front → back.
  static List<ProgressiveCabinRow> progressiveCabinRows({
    required List<int> rowCounts,
    required int availableSeatCount,
  }) {
    if (rowCounts.isEmpty) return const [];

    final maxSeats = rowCounts.fold<int>(0, (sum, n) => sum + n);
    if (maxSeats <= 0) return const [];

    var selected = availableSeatCount;
    if (selected < 1) selected = 1;
    if (selected > maxSeats) selected = maxSeats;

    // Last layout row index that contains a selected passenger seat.
    var covered = 0;
    var lastVisibleRow = 0;
    for (var i = 0; i < rowCounts.length; i++) {
      covered += rowCounts[i];
      lastVisibleRow = i;
      if (covered >= selected) break;
    }

    var seatIndex = 0;
    final rows = <ProgressiveCabinRow>[];
    for (var row = 0; row <= lastVisibleRow; row++) {
      final count = rowCounts[row];
      final passengers = <ProgressiveCabinSeat>[];
      for (var col = 0; col < count; col++) {
        passengers.add(
          ProgressiveCabinSeat(isAvailable: seatIndex < selected),
        );
        seatIndex++;
      }
      rows.add(
        ProgressiveCabinRow(
          layoutRowIndex: row,
          showDriver: row == 0,
          passengerSeats: passengers,
        ),
      );
    }
    return rows;
  }
```

- [x] **Step 4: Re-run tests — expect PASS**

```bash
flutter test test/utils/progressive_cabin_rows_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare/lib/utils/seat_layout_helpers.dart rideshare/test/utils/progressive_cabin_rows_test.dart
git commit -m "feat: add progressive cabin row helper for create-trip seats"
```

---

### Task 2: Wire picker to progressive rows + animate shell height

**Files:**
- Modify: `rideshare/lib/widgets/vehicle_seat_layout_picker.dart`

**Interfaces:**
- Consumes: `SeatLayoutHelpers.rowSeatCounts`, `SeatLayoutHelpers.progressiveCabinRows`
- Produces: same public `VehicleSeatLayoutPicker` API (no signature change)

- [x] **Step 1: Replace full-layout `_CarCabin` body with progressive rows**

In `VehicleSeatLayoutPicker.build`, keep computing `rowCounts` / `maxSeats` / `selected` as today.

Change `_CarCabin` to take progressive rows instead of full `rowCounts` + raw count:

```dart
class _CarCabin extends StatelessWidget {
  const _CarCabin({
    required this.cabinRows,
    required this.width,
  });

  final List<ProgressiveCabinRow> cabinRows;
  final double width;
  // ...
}
```

Inside `VehicleSeatLayoutPicker` `LayoutBuilder`:

```dart
final cabinRows = SeatLayoutHelpers.progressiveCabinRows(
  rowCounts: rowCounts,
  availableSeatCount: selected,
);

// ...
_CarCabin(
  cabinRows: cabinRows,
  width: cabinWidth,
),
```

In `_CarCabin.build`:

1. Compute `maxSlots` from visible rows only (`showDriver ? passengers+1 : passengers.length`).
2. Build seat widgets from `cabinRows` (driver tile when `showDriver`, then each `ProgressiveCabinSeat`).
3. Wrap the painted cabin in:

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeInOut,
  alignment: Alignment.topCenter,
  child: CustomPaint(
    painter: _CarBodyPainter(/* existing colors */),
    child: Padding(
      padding: EdgeInsets.only(
        top: seatSize * 0.85,
        bottom: seatSize * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: /* progressive row widgets */,
      ),
    ),
  ),
);
```

Do **not** draw layout rows beyond `cabinRows`. Inactive tiles only appear for `!isAvailable` seats inside those visible rows.

Keep `_SeatTile`, `_DriverPlaceholder`, `_CarBodyPainter`, legend, and stepper unchanged aside from the data source swap.

- [x] **Step 2: Analyze**

Run from `rideshare`:

```bash
dart analyze lib/widgets/vehicle_seat_layout_picker.dart lib/utils/seat_layout_helpers.dart
```

Expected: no errors / no warnings introduced by this change.

- [x] **Step 3: Re-run unit tests**

```bash
flutter test test/utils/progressive_cabin_rows_test.dart
```

Expected: PASS.

- [ ] **Step 4: Manual smoke (device/emulator)**

On create-trip step 2 with a sedan layout:

1. Start at 4 → full cabin, 4 green seats.
2. Decrease to 2 → rear row stays but 2 inactive; cabin may stay same height (2 rows).
3. Decrease to 1 → rear row disappears; cabin shortens with ~250ms animation.
4. Increase back to 4 → rows reappear, seats turn green in order.
5. Confirm prevent-mixing card + family hint still visible (no regression).

- [ ] **Step 5: Commit (only if user requested)**

```bash
git add rideshare/lib/widgets/vehicle_seat_layout_picker.dart
git commit -m "feat: animate progressive cabin length with available seats"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Layout shape from vehicle type; no row editors | Already in wizard; picker unchanged API |
| `+/-` clamps `1..maxLayoutSeats` | Existing picker + Task 1 clamp |
| Progressive visible rows (option B) | Task 1 + 2 |
| Partial last row inactive | Task 1 flags + Task 2 tiles |
| Driver never counted | Task 1 `showDriver` / existing placeholder |
| ~250ms height animation | Task 2 `AnimatedSize` |
| CustomPainter only, no PNG crops | Task 2 (existing painter) |
| Prevent mixing + family note | Already in `step2_details.dart` — no change |

## Out of scope (do not do in this plan)

- Regenerating mockup crops / shipping car PNGs
- Changing backend seat generation / publish payload
- Bus special-case grid redesign (uses same progressive helper)
- Vehicle settings UX changes
