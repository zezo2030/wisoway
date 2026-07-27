import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/presence_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/presence_models.dart';
import 'package:rideshare/screens/passenger/presence_confirmation_screen.dart';

class _FakePresenceGateway implements PresenceGateway {
  _FakePresenceGateway(this.prompt);

  final PresencePrompt prompt;
  PassengerPresenceStatus? declaredStatus;
  List<String> declaredSeats = const [];

  @override
  Future<PresencePrompt> getPrompt(String bookingId) async => prompt;

  @override
  Future<void> declare(
    String bookingId,
    PassengerPresenceStatus status,
    List<String> seatNumbers,
  ) async {
    declaredStatus = status;
    declaredSeats = seatNumbers;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arabic passenger can confirm every seat in the booking', (
    tester,
  ) async {
    final gateway = _FakePresenceGateway(_openPrompt());
    tester.view.physicalSize = const Size(887, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(gateway));
    await tester.pump();

    expect(find.text('تأكيد التواجد في السيارة'), findsOneWidget);
    expect(find.text('هل أنت داخل السيارة؟'), findsOneWidget);
    expect(find.text('نعم، أنا داخل السيارة'), findsOneWidget);
    expect(find.text('أنا في طريقي لمقابلة السائق'), findsOneWidget);
    expect(find.text('لست داخل السيارة'), findsOneWidget);

    await tester.tap(find.text('نعم، أنا داخل السيارة'));
    await tester.pump();

    expect(gateway.declaredStatus, PassengerPresenceStatus.inVehicle);
    expect(gateway.declaredSeats, ['1A', '1B']);
    expect(find.text('تم تأكيد تواجدك'), findsOneWidget);
  });

  testWidgets('closed confirmation window disables presence actions', (
    tester,
  ) async {
    final gateway = _FakePresenceGateway(_closedPrompt());

    await tester.pumpWidget(_testApp(gateway));
    await tester.pump();

    expect(find.text('انتهى وقت التأكيد'), findsOneWidget);
    expect(find.text('نعم، أنا داخل السيارة'), findsNothing);
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
