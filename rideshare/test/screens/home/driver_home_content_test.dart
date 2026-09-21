import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/providers/notification_provider.dart';
import 'package:rideshare/providers/trip_provider.dart';
import 'package:rideshare/screens/home/tabs/driver_home_content.dart';
import 'package:rideshare/screens/home/widgets/driver_home_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('DriverHomeContent dashboard', () {
    testWidgets('lays out the sections the driver mockup calls for', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DriverHomeContent)),
      );

      // Header, go-online card, publish CTA, location card.
      expect(find.text(l10n.driverHomeReadyTitle), findsOneWidget);
      expect(find.text(l10n.driverHomeReadySubtitle), findsOneWidget);
      expect(find.text(l10n.driverStatusLabel), findsOneWidget);
      expect(find.text(l10n.publishSharedTrip), findsOneWidget);
      expect(find.text(l10n.currentLocation), findsOneWidget);
      expect(find.text('ساق، العلا'), findsOneWidget);
      expect(find.text(l10n.showOnMapAction), findsOneWidget);
      expect(find.text(l10n.updateLocationAction), findsOneWidget);

      // Today's summary — the three tiles and the link under them.
      expect(find.text(l10n.todaySummary), findsOneWidget);
      expect(find.text(l10n.statNewRequests), findsOneWidget);
      expect(find.text(l10n.statTodayTrips), findsOneWidget);
      expect(find.text(l10n.statBookings), findsOneWidget);
      expect(find.text(l10n.viewAllStats), findsOneWidget);

      // Own trips — empty, since the stream has no trips in a test.
      expect(find.text(l10n.driverCurrentTripsTitle), findsOneWidget);
      expect(find.text(l10n.noPublishedTripsTitle), findsOneWidget);
      expect(find.text(l10n.publishTripNow), findsOneWidget);
    });

    testWidgets('keeps every card inside the screen width', (tester) async {
      await _pump(tester);

      // The dashboard is a column of full-bleed cards; anything wider than the
      // viewport would have overflowed the row inside it.
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      for (final card in find.byType(DriverHomeCard).evaluate()) {
        expect(
          tester.getSize(find.byWidget(card.widget)).width,
          lessThanOrEqualTo(width),
        );
      }
    });
  });
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final user = UserModel(
    id: 'd1',
    phoneNumber: '0790000000',
    email: 'd@example.com',
    name: 'محمد أحمد',
    gender: 'male',
    role: 'driver',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.5,
          maxScaleFactor: 0.5,
          child: child!,
        ),
        home: Scaffold(
          body: DriverHomeContent(
            user: user,
            userLocation: LocationModel(
              name: 'ساق، العلا',
              latitude: 26.6,
              longitude: 37.9,
            ),
            onOpenDrawer: () {},
            onRefreshLocation: () {},
            onChangeLocation: () {},
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}
