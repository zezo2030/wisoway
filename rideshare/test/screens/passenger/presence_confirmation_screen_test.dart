import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/presence_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/presence_models.dart';
import 'package:rideshare/screens/passenger/presence_confirmation_screen.dart';

class _FakePresenceGateway implements PresenceGateway {
  _FakePresenceGateway(this.prompt);

  PresencePrompt prompt;
  PassengerPresenceStatus? declaredStatus;
  List<String> declaredSeats = const [];

  @override
  Future<PresencePrompt> getPrompt(String bookingId) async => prompt;

  @override
  Future<PresencePrompt?> getPromptForTrip(String tripId) async => prompt;

  @override
  Future<void> declare(
    String bookingId,
    PassengerPresenceStatus status,
    List<String> seatNumbers,
  ) async {
    declaredStatus = status;
    declaredSeats = seatNumbers;
    prompt = _withStatus(prompt, seatNumbers, status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_FakePresenceGateway> open(
    WidgetTester tester, {
    PresencePrompt? prompt,
  }) async {
    final gateway = _FakePresenceGateway(prompt ?? _openPrompt());
    tester.view.physicalSize = const Size(887, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp(gateway));
    await tester.pump();
    return gateway;
  }

  testWidgets('each passenger on the booking answers separately', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('محمود'), findsOneWidget);
    expect(find.text('داخل السيارة'), findsNWidgets(2));
    expect(find.text('في الطريق'), findsNWidgets(2));
    expect(find.text('لن يستقل الرحلة'), findsNWidgets(2));
  });

  testWidgets('confirming one passenger leaves the other unanswered', (
    tester,
  ) async {
    final gateway = await open(tester);

    await tester.tap(find.text('داخل السيارة').first);
    await tester.pump();
    await tester.pump();

    expect(gateway.declaredStatus, PassengerPresenceStatus.inVehicle);
    expect(gateway.declaredSeats, ['1A']);
    expect(find.text('في الطريق'), findsOneWidget);
    expect(find.text('لن يستقل الرحلة'), findsOneWidget);
  });

  testWidgets('someone on the way can only say they arrived', (tester) async {
    await open(
      tester,
      prompt: _withStatus(_openPrompt(), [
        '1A',
      ], PassengerPresenceStatus.onMyWay),
    );

    expect(find.text('وصلت، داخل السيارة'), findsOneWidget);
    expect(find.text('لن يستقل الرحلة'), findsOneWidget);
    expect(find.text('داخل السيارة'), findsOneWidget);
  });

  testWidgets('not riding asks first, because it cannot be undone', (
    tester,
  ) async {
    final gateway = await open(tester);

    await tester.tap(find.text('لن يستقل الرحلة').first);
    await tester.pumpAndSettle();

    expect(find.text('لا يمكن التراجع عن هذا الاختيار.'), findsOneWidget);
    expect(gateway.declaredStatus, isNull);

    await tester.tap(find.text('نعم، لن يستقلها'));
    await tester.pumpAndSettle();

    expect(gateway.declaredStatus, PassengerPresenceStatus.notRiding);
    expect(gateway.declaredSeats, ['1A']);
  });

  testWidgets('with every answer final, no question remains', (tester) async {
    await open(
      tester,
      prompt: _withStatus(
        _withStatus(_openPrompt(), ['1A'], PassengerPresenceStatus.inVehicle),
        ['1B'],
        PassengerPresenceStatus.notRiding,
      ),
    );

    expect(find.text('تم تأكيد تواجدك'), findsOneWidget);
    expect(find.text('هل أنت داخل السيارة؟'), findsNothing);
  });

  testWidgets('closed confirmation window disables presence actions', (
    tester,
  ) async {
    final gateway = _FakePresenceGateway(_closedPrompt());

    await tester.pumpWidget(_testApp(gateway));
    await tester.pump();

    expect(find.text('انتهى وقت التأكيد'), findsOneWidget);
    expect(find.text('داخل السيارة'), findsNothing);
  });
}

Widget _testApp(PresenceGateway gateway) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: PresenceConfirmationScreen(
      bookingId: 'booking-1',
      presenceGateway: gateway,
    ),
  );
}

PresencePrompt _withStatus(
  PresencePrompt prompt,
  List<String> seatNumbers,
  PassengerPresenceStatus status,
) {
  return PresencePrompt(
    bookingId: prompt.bookingId,
    tripId: prompt.tripId,
    driver: prompt.driver,
    vehicle: prompt.vehicle,
    pickup: prompt.pickup,
    departureTime: prompt.departureTime,
    secondsUntilDeparture: prompt.secondsUntilDeparture,
    window: prompt.window,
    seats: [
      for (final seat in prompt.seats)
        PresencePromptSeat(
          seatNumber: seat.seatNumber,
          displayName: seat.displayName,
          isMainBooker: seat.isMainBooker,
          declaredStatus: seatNumbers.contains(seat.seatNumber)
              ? status
              : seat.declaredStatus,
        ),
    ],
  );
}

PresencePrompt _openPrompt() {
  final now = DateTime.now();
  return _prompt(
    PresenceWindow(
      opensAt: now.subtract(const Duration(minutes: 5)),
      closesAt: now.add(const Duration(minutes: 20)),
      isOpen: true,
    ),
  );
}

PresencePrompt _closedPrompt() {
  final now = DateTime.now();
  return _prompt(
    PresenceWindow(
      opensAt: now.subtract(const Duration(hours: 1)),
      closesAt: now.subtract(const Duration(minutes: 1)),
      isOpen: false,
    ),
  );
}

PresencePrompt _prompt(PresenceWindow window) {
  return PresencePrompt(
    bookingId: 'booking-1',
    tripId: 'trip-1',
    driver: const PresenceDriver(
      id: 'driver-1',
      name: 'أحمد محمود',
      rating: 4.9,
      ratingCount: 128,
    ),
    vehicle: const PresenceVehicle(
      vehicleType: 'أبيض',
      model: 'تويوتا كورولا',
      plateNumber: '22-12345',
    ),
    pickup: const PresencePoint(
      name: 'دوار المدينة الرياضية',
      address: 'أمام بوابة 2',
    ),
    departureTime: DateTime.now().add(const Duration(minutes: 5)),
    secondsUntilDeparture: 300,
    seats: const [
      PresencePromptSeat(
        seatNumber: '1A',
        displayName: 'أحمد',
        isMainBooker: true,
      ),
      PresencePromptSeat(
        seatNumber: '1B',
        displayName: 'محمود',
        isMainBooker: false,
      ),
    ],
    window: window,
  );
}
