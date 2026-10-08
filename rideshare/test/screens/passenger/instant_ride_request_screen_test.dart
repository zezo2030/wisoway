import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/core/errors/failure.dart';
import 'package:rideshare/core/services/instant_ride_service.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/instant_ride_models.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/screens/passenger/instant_ride_request_screen.dart';
import 'package:rideshare/screens/passenger/widgets/no_driver_found_sheet.dart';

void main() {
  testWidgets('a no_drivers request shows the no-driver sheet', (tester) async {
    await _pumpScreen(tester, request: _request('no_drivers'));

    expect(find.byType(NoDriverFoundSheet), findsOneWidget);
    expect(find.text("We couldn't find a driver right now"), findsOneWidget);
  });

  for (final reason in ['no_eligible_drivers', 'all_declined', 'ttl_expired']) {
    testWidgets('$reason: just says no driver is available', (tester) async {
      await _pumpScreen(
        tester,
        request: _request('no_drivers', terminalReason: reason),
      );

      expect(find.text('No driver is available right now.'), findsOneWidget);
      // No search radius, no pickup-point hint, no ask to pay more.
      expect(find.textContaining(' km'), findsNothing);
      expect(find.textContaining('pickup point'), findsNothing);
    });
  }

  testWidgets('an expired request shows the same sheet', (tester) async {
    await _pumpScreen(tester, request: _request('expired'));

    expect(find.byType(NoDriverFoundSheet), findsOneWidget);
  });

  testWidgets('a cancelled request does not use the no-driver sheet', (
    tester,
  ) async {
    await _pumpScreen(tester, request: _request('cancelled'));

    expect(find.byType(NoDriverFoundSheet), findsNothing);
    expect(find.text('Request cancelled'), findsOneWidget);
  });

  testWidgets('retry posts the finished request id and resumes searching', (
    tester,
  ) async {
    final service = _FakeInstantRideService(
      retryResult: _request('searching', id: 'req-2'),
    );
    await _pumpScreen(
      tester,
      request: _request('no_drivers', id: 'req-1'),
      service: service,
    );

    await tester.tap(find.text('Try again'));
    // Not pumpAndSettle: the searching state polls on a periodic timer and
    // spins a progress indicator, so the tree never goes quiet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.retriedIds, ['req-1']);
    expect(find.byType(NoDriverFoundSheet), findsNothing);
    expect(find.text('Finding the nearest driver...'), findsOneWidget);

    await _disposeScreen(tester);
  });

  testWidgets('double-tapping retry only sends one request', (tester) async {
    final service = _FakeInstantRideService(
      retryResult: _request('searching', id: 'req-2'),
      retryDelay: const Duration(milliseconds: 200),
    );
    await _pumpScreen(
      tester,
      request: _request('no_drivers', id: 'req-1'),
      service: service,
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Try again'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 250));

    expect(service.retriedIds, ['req-1']);

    await _disposeScreen(tester);
  });

  testWidgets('a failed retry keeps the sheet and the trip on screen', (
    tester,
  ) async {
    final service = _FakeInstantRideService(
      retryError: const Failure(
        category: FailureCategory.network,
        messageKey: 'errorNetwork',
        severity: FailureSeverity.error,
        developerDetail: 'offline',
      ),
    );
    await _pumpScreen(
      tester,
      request: _request('no_drivers', id: 'req-1'),
      service: service,
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(NoDriverFoundSheet), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the form shows the fixed fare read-only and requests with it', (
    tester,
  ) async {
    final service = _FakeInstantRideService();
    await _pumpForm(tester, service);

    expect(find.text('Trip fare'), findsOneWidget);
    expect(find.text('4.50 JOD'), findsOneWidget);
    expect(find.text('12.3 km · 18 min'), findsOneWidget);
    expect(
      find.text(
        'The fare is calculated from the distance. Pay the driver in cash.',
      ),
      findsOneWidget,
    );
    // Nothing to type or nudge: no fare field, no − / + steppers.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);

    final cta = find.widgetWithText(ElevatedButton, 'Request now');
    expect(tester.widget<ElevatedButton>(cta).onPressed, isNotNull);

    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.createdRequests, 1);
    expect(find.text('Finding the nearest driver...'), findsOneWidget);
    await _disposeScreen(tester);
  });

  testWidgets('a failed quote offers a retry and holds the request back', (
    tester,
  ) async {
    final service = _FakeInstantRideService(quoteFailures: 1);
    await _pumpForm(tester, service);

    expect(find.text("Couldn't calculate the trip fare."), findsOneWidget);
    final cta = find.widgetWithText(ElevatedButton, 'Request now');
    expect(tester.widget<ElevatedButton>(cta).onPressed, isNull);

    await tester.ensureVisible(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.quoteCalls, 2);
    expect(find.text('4.50 JOD'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(cta).onPressed, isNotNull);
    await _disposeScreen(tester);
  });

  testWidgets('a searching request shows the progress steps and cancel', (
    tester,
  ) async {
    // Not _pumpScreen: the search ring animates and the request polls on a
    // timer, so the tree never settles.
    await tester.pumpWidget(
      _app(
        InstantRideRequestScreen(
          initialRequest: _request('searching', id: 'req-1'),
          service: _FakeInstantRideService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Finding the nearest driver...'), findsOneWidget);
    expect(find.text('Reaching out to drivers near you'), findsOneWidget);
    for (final step in [
      'Request sent',
      'Finding a driver',
      'Driver accepts',
      'Driver on the way',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Cancel request'), findsOneWidget);
    await _disposeScreen(tester);
  });

  testWidgets('the searching sheet shows the fixed fare with no way to raise', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        InstantRideRequestScreen(
          initialRequest: _request(
            'searching',
            id: 'req-1',
            passengerFare: '5.00',
            maxFare: 5,
          ),
          service: _FakeInstantRideService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Trip fare'), findsOneWidget);
    expect(find.text('5 JOD'), findsOneWidget);
    expect(find.text('Raise fare'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    await _disposeScreen(tester);
  });

  testWidgets('a matched request shows the driver card and actions', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      request: _request(
        'accepted',
        match: const InstantMatch(
          currency: 'JOD',
          tripId: 'trip-1',
          bookingId: 'bk-1',
          driverId: 'drv-1',
          driverName: 'Mohammed Ahmed',
          driverRating: 4.9,
          vehicleModel: 'Hyundai Sonata',
          plateNumber: 'A B C 1234',
          pickupEtaSeconds: 180,
        ),
      ),
    );

    expect(find.text('Driver found!'), findsOneWidget);
    expect(find.text('Mohammed Ahmed'), findsOneWidget);
    expect(find.text('A B C 1234'), findsOneWidget);
    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Track ride'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
  });

  testWidgets('closing the finished request pops without cancelling it', (
    tester,
  ) async {
    final service = _FakeInstantRideService();
    await _pumpScreen(
      tester,
      request: _request('no_drivers', id: 'req-1'),
      service: service,
      pushed: true,
    );

    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();

    expect(service.cancelledIds, isEmpty);
    expect(find.byType(NoDriverFoundSheet), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the support link opens the support route', (tester) async {
    await _pumpScreen(tester, request: _request('no_drivers'));

    await tester.ensureVisible(find.text('Contact support'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();

    expect(find.text('support screen'), findsOneWidget);
  });
}

InstantRequest _request(
  String status, {
  String id = 'req-1',
  InstantMatch? match,
  String? passengerFare,
  double? maxFare,
  String? terminalReason,
}) {
  return InstantRequest(
    id: id,
    passengerFare: passengerFare,
    recommendedFare: passengerFare,
    maxFare: maxFare,
    terminalReason: terminalReason,
    match: match,
    tripId: match?.tripId,
    status: status,
    fromName: 'Abdali',
    toName: 'Airport',
    currency: 'JOD',
    seatCount: 1,
    canRetry: status == 'no_drivers' || status == 'expired',
  );
}

final _from = LocationModel(
  name: 'Abdali',
  latitude: 31.9628,
  longitude: 35.9106,
);
final _to = LocationModel(
  name: 'Airport',
  latitude: 31.7226,
  longitude: 35.9932,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required InstantRequest request,
  _FakeInstantRideService? service,
  bool pushed = false,
}) async {
  // A phone-sized viewport; the default 800x600 test window is wider and
  // shorter than any real device and pushes the sheet off-screen.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final screen = InstantRideRequestScreen(
    initialFrom: _from,
    initialTo: _to,
    initialRequest: request,
    service: service ?? _FakeInstantRideService(),
  );

  await tester.pumpWidget(_app(pushed ? _Launcher(screen: screen) : screen));
  await tester.pumpAndSettle();

  if (pushed) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

/// Opens the input form with both ends set, so the screen fetches the quote.
Future<void> _pumpForm(
  WidgetTester tester,
  _FakeInstantRideService service,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _app(
      InstantRideRequestScreen(
        initialFrom: _from,
        initialTo: _to,
        service: service,
      ),
    ),
  );
  // One frame for the post-frame quote fetch, one for its answer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The screen's host app: theme, English strings, and the support route.
Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routes: {
      RouteNames.support: (_) => const Scaffold(body: Text('support screen')),
    },
    home: home,
  );
}

/// Replaces the screen so its polling timers are cancelled before the test ends.
Future<void> _disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Hosts the screen behind a route so `maybePop` has somewhere to go.
class _Launcher extends StatelessWidget {
  final Widget screen;

  const _Launcher({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            const Text('home'),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('open'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeInstantRideService extends InstantRideService {
  final InstantRequest? retryResult;
  final Object? retryError;
  final Duration retryDelay;

  /// How many quote calls fail before one succeeds.
  int quoteFailures;

  final List<String> retriedIds = [];
  final List<String> cancelledIds = [];
  int quoteCalls = 0;
  int createdRequests = 0;

  _FakeInstantRideService({
    this.retryResult,
    this.retryError,
    this.retryDelay = Duration.zero,
    this.quoteFailures = 0,
  });

  @override
  Future<InstantRequest> retryRequest(String id) async {
    retriedIds.add(id);
    if (retryDelay > Duration.zero) await Future<void>.delayed(retryDelay);
    if (retryError != null) throw retryError!;
    return retryResult ?? _request('searching', id: 'req-2');
  }

  @override
  Future<InstantQuote> getQuote({
    required LocationModel from,
    required LocationModel to,
  }) async {
    quoteCalls++;
    if (quoteFailures > 0) {
      quoteFailures--;
      throw const Failure(
        category: FailureCategory.network,
        messageKey: 'errorNetwork',
        severity: FailureSeverity.error,
        developerDetail: 'offline',
      );
    }
    return const InstantQuote(
      recommendedFare: 4.5,
      minFare: 4.5,
      maxFare: 4.5,
      currency: 'JOD',
      distanceKm: 12.3,
      durationMinutes: 18,
    );
  }

  @override
  Future<InstantRequest> createRequest({
    required LocationModel from,
    required LocationModel to,
    int seatCount = 1,
  }) async {
    createdRequests++;
    return _request('searching', id: 'req-new', passengerFare: '4.50');
  }

  @override
  Future<InstantRequest> cancelRequest(String id) async {
    cancelledIds.add(id);
    return _request('cancelled', id: id);
  }

  @override
  Future<InstantRequest> getRequest(String id) async =>
      _request('searching', id: id);

  @override
  Future<List<InstantNearbyDriverPin>> nearbyDriverPins({
    required double latitude,
    required double longitude,
  }) async => const [];
}
