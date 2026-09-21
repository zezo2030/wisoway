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
