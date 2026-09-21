import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/screens/driver/trip_summary_screen.dart';

/// The trip summary used to fall back to `seatPrice * billableSeats * 0.10` —
/// a literal 10% applied to presence-confirmed seats — and then back-derived a
/// percentage from that amount. The fee is charged on the trip's TOTAL seats at
/// a server-configured rate, so both the amount and the derived percentage were
/// wrong whenever the car did not fill.
void main() {
  group('resolveTripSummaryFee', () {
    test('prefers what the settlement reported', () {
      expect(
        resolveTripSummaryFee(
          capturedFromSettlement: 1.6,
          capturedOnTrip: '9.99',
          quotedAmount: 2.0,
        ),
        1.6,
      );
    });

    test('a settlement reporting 0.00 is a real zero, not a missing value', () {
      expect(
        resolveTripSummaryFee(
          capturedFromSettlement: 0,
          capturedOnTrip: '1.60',
          quotedAmount: 1.6,
        ),
        0,
      );
    });

    test('falls back to the amount stamped on the trip', () {
      expect(
        resolveTripSummaryFee(
          capturedFromSettlement: null,
          capturedOnTrip: '1.60',
          quotedAmount: 2.0,
        ),
        1.6,
      );
    });

    test('falls back to the server quote, never to a local percentage', () {
      // 4 seats * 4.00 * 10% = 1.60 — the all-seats basis the backend charges
      // on. A local 10%-of-ridden-seats guess with 2 riders would say 0.80.
      expect(
        resolveTripSummaryFee(
          capturedFromSettlement: null,
          capturedOnTrip: null,
          quotedAmount: 1.6,
        ),
        1.6,
      );
    });

    test('is null when nothing is known — the UI renders a placeholder', () {
      expect(
        resolveTripSummaryFee(
          capturedFromSettlement: null,
          capturedOnTrip: null,
          quotedAmount: null,
        ),
        isNull,
      );
    });

    test('rounds to fils', () {
      expect(
        resolveTripSummaryFee(
          capturedFromSettlement: 1.6049,
          capturedOnTrip: null,
          quotedAmount: null,
        ),
        1.6,
      );
    });
  });
}
