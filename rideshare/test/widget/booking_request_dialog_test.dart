import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/booking_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/booking_request.dart';
import 'package:rideshare/widgets/booking_request_dialog.dart';

class _FakeBookingService extends BookingService {
  final accepted = <String>[];
  final rejected = <String>[];

  @override
  Future<BookingModel> acceptBooking(String bookingId) async {
    accepted.add(bookingId);
    return BookingModel(
      id: bookingId,
      tripId: 't-1',
      userId: 'p-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<BookingModel> rejectBooking(String bookingId, {String? reason}) async {
    rejected.add(bookingId);
    return BookingModel(
      id: bookingId,
      tripId: 't-1',
      userId: 'p-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  BookingRequest request({Duration left = const Duration(hours: 2)}) =>
      BookingRequest.fromJson({
        'id': 'b-1',
        'tripId': 't-1',
        'seatCount': 2,
        'totalAmount': '10.00',
        'currency': 'JOD',
        'expiresAt': DateTime.now().add(left).toUtc().toIso8601String(),
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'passenger': {'name': 'ayat', 'gender': 'female', 'rating': '4.50'},
        'seats': [
          {'seatNumber': '1-0', 'displayName': 'ayat', 'isMainBooker': true},
          {'seatNumber': '1-1', 'displayName': 'محمد', 'isMainBooker': false},
        ],
        'trip': {
          'seatLayout': {
            'rows': 2,
            'seatsPerRow': 3,
            'seatsPerRowList': [1, 3],
          },
          'fromName': 'Al Ula Old town',
          'toName': 'Medina',
          'departureTime': DateTime.now()
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String(),
        },
      });

  Future<BookingRequestOutcome?> open(
    WidgetTester tester,
    BookingRequest r,
    BookingService service,
  ) async {
    BookingRequestOutcome? outcome;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  outcome = await showDialog<BookingRequestOutcome>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        BookingRequestDialog(request: r, service: service),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return outcome;
  }

  testWidgets('shows the passenger, amount, seats and time left', (
    tester,
  ) async {
    await open(tester, request(), _FakeBookingService());

    expect(find.text('طلب حجز جديد'), findsOneWidget);
    expect(find.text('ayat'), findsOneWidget);
    expect(find.text('10.00 JOD'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('ينتهي الطلب خلال'), findsOneWidget);
  });

  testWidgets('lists each seat by its seat-map number, companion marked', (
    tester,
  ) async {
    await open(tester, request(), _FakeBookingService());

    expect(find.text('مقعد 2 · ayat'), findsOneWidget);
    expect(find.text('مقعد 3 · محمد'), findsOneWidget);
    expect(find.text('مرافق'), findsOneWidget);
  });

  testWidgets('back does not dismiss it', (tester) async {
    await open(tester, request(), _FakeBookingService());

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('طلب حجز جديد'), findsOneWidget);
  });

  testWidgets('accepting calls the service and closes the card', (
    tester,
  ) async {
    final service = _FakeBookingService();
    await open(tester, request(), service);

    await tester.tap(find.text('قبول الحجز'));
    await tester.pumpAndSettle();

    expect(service.accepted, ['b-1']);
    expect(find.text('طلب حجز جديد'), findsNothing);
  });

  testWidgets('declining asks for confirmation first', (tester) async {
    final service = _FakeBookingService();
    await open(tester, request(), service);

    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    expect(find.text('رفض طلب الحجز؟'), findsOneWidget);
    expect(service.rejected, isEmpty);

    await tester.tap(find.text('رفض').last);
    await tester.pumpAndSettle();

    expect(service.rejected, ['b-1']);
    expect(find.text('طلب حجز جديد'), findsNothing);
  });

  testWidgets('closes itself when the window runs out', (tester) async {
    await open(
      tester,
      request(left: const Duration(seconds: 2)),
      _FakeBookingService(),
    );
    expect(find.text('طلب حجز جديد'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('طلب حجز جديد'), findsNothing);
  });
}
