import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/core/services/ride_payment_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/ride_payment.dart';
import 'package:rideshare/models/seat_data.dart';
import 'package:rideshare/models/seat_layout_config.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/providers/trip_provider.dart';
import 'package:rideshare/screens/passenger/ride_payment_due_screen.dart';

/// The server's view of the passenger's fare, changed between polls.
class _FakePayments extends RidePaymentService {
  _FakePayments(this.payment);
  RidePayment payment;
  final List<String> calls = [];

  @override
  Future<RidePayment> getMine(String tripId) async => payment;

  @override
  Future<RidePayment> retryCliq(String bookingId, {String? payerCliqAlias}) {
    calls.add('retry');
    payment = _payment(method: 'cliq', status: 'requested');
    return Future.value(payment);
  }

  @override
  Future<RidePayment> switchToCash(String bookingId) {
    calls.add('cash');
    payment = _payment();
    return Future.value(payment);
  }
}

class _FakeTripProvider extends TripProvider {
  @override
  Future<TripModel?> getTrip(String tripId) async => _trip;
}

RidePayment _payment({String method = 'cash', String status = 'pending'}) =>
    RidePayment(
      bookingId: 'b-1',
      tripId: 't-1',
      passengerId: 'p-1',
      amount: 2.5,
      currency: 'JOD',
      method: method,
      status: status,
      payerCliqAlias: method == 'cliq' ? '00962791234567' : null,
    );

final _trip = TripModel(
  id: 't-1',
  driverId: 'd-1',
  driverName: 'Ahmad',
  from: LocationModel(name: 'Abdali', latitude: 31.96, longitude: 35.91),
  to: LocationModel(name: 'Sweifieh', latitude: 31.95, longitude: 35.86),
  departureTime: DateTime.now(),
  price: 2.5,
  currency: 'JOD',
  totalSeats: 1,
  availableSeats: 0,
  status: 'completed',
  tripType: 'instant',
  seatLayout: SeatLayoutConfig(rows: 1, seatsPerRow: 1),
  seats: const <SeatData>[],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

Future<_FakePayments> _pump(WidgetTester tester, RidePayment payment) async {
  final payments = _FakePayments(payment);
  await tester.pumpWidget(
    ChangeNotifierProvider<TripProvider>.value(
      value: _FakeTripProvider(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => settings.name == RouteNames.rating
              ? const Scaffold(body: Text('rating-screen'))
              : RidePaymentDueScreen(tripId: 't-1', service: payments),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return payments;
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('cash: asks the passenger to pay the driver', (tester) async {
    await _pump(tester, _payment());

    expect(find.text('Please pay the driver for the trip'), findsOneWidget);
    expect(find.text('2.50 JOD'), findsOneWidget);
    expect(
      find.text('Waiting for the driver to confirm payment…'),
      findsOneWidget,
    );
    await _dispose(tester);
  });

  testWidgets('CliQ: says where the request went and waits for the bank', (
    tester,
  ) async {
    await _pump(tester, _payment(method: 'cliq', status: 'requested'));

    expect(find.textContaining('00962791234567'), findsOneWidget);
    expect(find.text('Waiting for the bank to confirm…'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('failed CliQ: retry or pay cash instead', (tester) async {
    final payments = await _pump(
      tester,
      _payment(method: 'cliq', status: 'failed'),
    );

    expect(find.text("The CliQ payment didn't go through."), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-switch-cash')));
    await tester.pump();

    expect(payments.calls, ['cash']);
    expect(find.text('Please pay the driver for the trip'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('back does not leave before the fare is settled', (
    tester,
  ) async {
    await _pump(tester, _payment());

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue); // swallowed, not exited
    expect(find.text('2.50 JOD'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('moves on to rating once paid', (tester) async {
    final payments = await _pump(tester, _payment());

    payments.payment = _payment(status: 'paid');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('rating-screen'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('a reported non-payment is explained', (tester) async {
    final payments = await _pump(tester, _payment());

    payments.payment = _payment(status: 'disputed');
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Payment not recorded'), findsOneWidget);
    await _dispose(tester);
  });
}
