import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/vehicle_art.dart';

/// Mirrors SUPPORTED_VEHICLE_TYPES / seatsPerRowList in the backend catalog
/// (rideshare-backend/src/modules/vehicles/vehicle-types.ts). If a layout
/// changes there, this list changes here and the artwork gets recalibrated —
/// the two must never drift.
const _backendLayouts = <String, List<int>>{
  'standard_car': [1, 3],
  'family_suv': [1, 3, 2],
  'medium_bus': [1, 3, 3, 3],
  'large_bus': [1, 3, 3, 3, 3, 3, 2, 4],
};

void main() {
  group('vehicle art catalog', () {
    test('covers every backend vehicle type', () {
      for (final type in _backendLayouts.keys) {
        expect(vehicleArtFor(type), isNotNull, reason: '$type has no artwork');
      }
    });

    test('returns null for retired and unknown types', () {
      for (final type in [
        'sedan',
        'suv',
        'van',
        'truck',
        'bus',
        'small_bus',
        'spaceship',
      ]) {
        expect(vehicleArtFor(type), isNull);
      }
      expect(vehicleArtFor(null), isNull);
    });

    test('resolves case-insensitively and ignores stray whitespace', () {
      expect(vehicleArtFor('  LARGE_BUS '), isNotNull);
    });

    _backendLayouts.forEach((type, rowCounts) {
      final expectedSeats = rowCounts.fold<int>(0, (a, b) => a + b);

      test('$type draws all $expectedSeats seats in backend order', () {
        final art = vehicleArtFor(type)!;
        expect(art.seatCount, expectedSeats);

        // Walking seatsPerRowList must reproduce the exact (row, col) sequence
        // the API generates, so display seat n maps to backend seat `row-col`.
        final expected = <String>[
          for (var r = 0; r < rowCounts.length; r++)
            for (var c = 0; c < rowCounts[r]; c++) '$r-$c',
        ];
        final actual = [for (final s in art.seats) '${s.row}-${s.col}'];
        expect(actual, expected);
      });

      test('$type seat rectangles stay inside the artwork', () {
        final art = vehicleArtFor(type)!;
        expect(art.aspectRatio, greaterThan(0));

        for (final s in art.seats) {
          expect(s.width, greaterThan(0));
          expect(s.height, greaterThan(0));
          expect(s.left, inInclusiveRange(0.0, 1.0));
          expect(s.top, inInclusiveRange(0.0, 1.0));
          expect(s.left + s.width, lessThanOrEqualTo(1.0));
          expect(s.top + s.height, lessThanOrEqualTo(1.0));
        }
      });

      test('$type seats do not overlap each other', () {
        final art = vehicleArtFor(type)!;
        for (var i = 0; i < art.seats.length; i++) {
          for (var j = i + 1; j < art.seats.length; j++) {
            final a = art.seats[i], b = art.seats[j];
            final overlaps = a.left < b.left + b.width &&
                b.left < a.left + a.width &&
                a.top < b.top + b.height &&
                b.top < a.top + a.height;
            expect(overlaps, isFalse,
                reason: 'seat ${i + 1} overlaps seat ${j + 1} in $type');
          }
        }
      });
    });
  });
}
