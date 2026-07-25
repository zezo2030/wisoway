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

  testWidgets('a re-priced retry returns to the form with the new fare', (
    tester,
  ) async {
    final service = _FakeInstantRideService(
      retryError: const InstantRetryFareChangedException(
        InstantQuote(
          recommendedFare: 4.5,
          minFare: 3,
          maxFare: 9,
          currency: 'JOD',
          distanceKm: 5,
        ),
      ),
    );
    await _pumpScreen(
      tester,
      request: _request('no_drivers', id: 'req-1'),
      service: service,
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(NoDriverFoundSheet), findsNothing);
    expect(
      find.text('The fare range changed. Review the fare before trying again.'),
      findsOneWidget,
    );
    expect(find.text('4.50 JOD'), findsOneWidget);
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

InstantRequest _request(String status, {String id = 'req-1'}) {
  return InstantRequest(
    id: id,
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

  await tester.pumpWidget(
    MaterialApp(
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
        RouteNames.support: (_) =>
            const Scaffold(body: Text('support screen')),
      },
      home: pushed ? _Launcher(screen: screen) : screen,
    ),
  );
  await tester.pumpAndSettle();

  if (pushed) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => screen),
              ),
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

  final List<String> retriedIds = [];
  final List<String> cancelledIds = [];

  _FakeInstantRideService({
    this.retryResult,
    this.retryError,
    this.retryDelay = Duration.zero,
  });

  @override
  Future<InstantRequest> retryRequest(String id) async {
    retriedIds.add(id);
    if (retryDelay > Duration.zero) await Future<void>.delayed(retryDelay);
    if (retryError != null) throw retryError!;
    return retryResult ?? _request('searching', id: 'req-2');
  }

  @override
  Future<InstantRequest> cancelRequest(String id) async {
    cancelledIds.add(id);
    return _request('cancelled', id: id);
  }

  @override
  Future<InstantRequest> getRequest(String id) async =>
      _request('searching', id: id);
}
