import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rideshare/core/services/location_service.dart';
import 'package:rideshare/core/services/saved_places_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/screens/location/route_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Location service whose autocomplete responses the test completes by hand,
/// so out-of-order replies can be reproduced deterministically.
class _FakeLocationService extends LocationService {
  final Map<String, Completer<LocationAutocompleteResult>> pending = {};
  final List<String> queries = [];
  final List<double?> sentLatitudes = [];

  /// Queries answered immediately instead of parked in [pending].
  final Map<String, List<PlaceSuggestion>> canned = {};

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationAutocompleteResult> autocomplete({
    required String query,
    String? lang,
    String? sessionToken,
    double? latitude,
    double? longitude,
    dynamic cancelToken,
  }) {
    queries.add(query);
    sentLatitudes.add(latitude);

    final immediate = canned[query];
    if (immediate != null) {
      return Future.value(
        LocationAutocompleteResult(
          sessionToken: sessionToken ?? '',
          suggestions: immediate,
        ),
      );
    }

    final completer = Completer<LocationAutocompleteResult>();
    pending[query] = completer;
    return completer.future;
  }

  void complete(String query, List<PlaceSuggestion> suggestions) {
    pending.remove(query)?.complete(
      LocationAutocompleteResult(sessionToken: 't', suggestions: suggestions),
    );
  }

  @override
  Future<LocationModel> placeDetail({
    required String placeId,
    String? sessionToken,
    dynamic cancelToken,
  }) async {
    return LocationModel(
      name: 'resolved-$placeId',
      latitude: 31.9,
      longitude: 35.9,
      address: 'resolved-$placeId',
    );
  }
}

PlaceSuggestion _suggestion(String name, {int? distanceMeters}) {
  return PlaceSuggestion(
    placeId: name,
    primaryText: name,
    secondaryText: 'عمّان',
    description: name,
    distanceMeters: distanceMeters,
  );
}

void main() {
  late _FakeLocationService service;
  late SavedPlacesService savedPlaces;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _FakeLocationService();
    savedPlaces = SavedPlacesService(userId: 'user-1');
  });

  Future<RouteSelection?> pumpScreen(
    WidgetTester tester, {
    RouteField focus = RouteField.origin,
    LocationModel? from,
    LocationModel? to,
  }) async {
    RouteSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<RouteSelection>(
                    MaterialPageRoute(
                      builder: (_) => RouteSearchScreen(
                        focusField: focus,
                        savedPlaces: savedPlaces,
                        from: from,
                        to: to,
                        locationService: service,
                      ),
                    ),
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
    await tester.pumpAndSettle();
    return result;
  }

  group('RouteSearchScreen', () {
    testWidgets('shows the map option before anything is typed', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('اختيار على الخريطة'), findsOneWidget);
      expect(service.queries, isEmpty);
    });

    testWidgets('fills the idle space with a map of where the user is', (
      tester,
    ) async {
      await pumpScreen(tester);

      // The screen must open on something to act on, not on empty white.
      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('hides the map once results take over the screen', (
      tester,
    ) async {
      service.canned['عمان'] = [_suggestion('وسط البلد')];
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'عمان');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('وسط البلد', findRichText: true), findsOneWidget);
      expect(find.byType(GoogleMap), findsNothing);
    });

    testWidgets('swapping exchanges the two endpoints', (tester) async {
      await pumpScreen(
        tester,
        from: LocationModel(name: 'إربد', latitude: 32.55, longitude: 35.85),
        to: LocationModel(name: 'عمّان', latitude: 31.95, longitude: 35.91),
      );

      await tester.tap(find.byTooltip('تبديل نقطتي الانطلاق والوصول'));
      await tester.pumpAndSettle();

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller?.text, 'عمّان');
      expect(fields[1].controller?.text, 'إربد');
    });

    testWidgets('does not search until two characters are typed', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'ع');
      await tester.pump(const Duration(milliseconds: 600));

      expect(service.queries, isEmpty);
      // The default list stays put rather than flashing an empty result state.
      expect(find.text('اختيار على الخريطة'), findsOneWidget);
    });

    testWidgets('debounces so a burst of keystrokes issues one request', (
      tester,
    ) async {
      await pumpScreen(tester);
      final field = find.byType(TextField).first;

      await tester.enterText(field, 'عم');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(field, 'عما');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.enterText(field, 'عمان');
      await tester.pump(const Duration(milliseconds: 400));

      expect(service.queries, ['عمان']);

      service.complete('عمان', [_suggestion('جبل الحسين')]);
      await tester.pumpAndSettle();
      expect(find.text('جبل الحسين', findRichText: true), findsOneWidget);
    });

    testWidgets('ignores a stale response that lands after a newer one', (
      tester,
    ) async {
      await pumpScreen(tester);
      final field = find.byType(TextField).first;

      await tester.enterText(field, 'عما');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field, 'عمان');
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.queries, ['عما', 'عمان']);

      // The newer answer arrives first, then the older one.
      service.complete('عمان', [_suggestion('نتيجة جديدة')]);
      await tester.pumpAndSettle();
      service.complete('عما', [_suggestion('نتيجة قديمة')]);
      await tester.pumpAndSettle();

      expect(find.text('نتيجة جديدة', findRichText: true), findsOneWidget);
      expect(find.text('نتيجة قديمة', findRichText: true), findsNothing);
    });

    testWidgets('drops a response that arrives after the field is cleared', (
      tester,
    ) async {
      await pumpScreen(tester);
      final field = find.byType(TextField).first;

      await tester.enterText(field, 'عمان');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field, '');
      await tester.pumpAndSettle();

      service.complete('عمان', [_suggestion('متأخرة')]);
      await tester.pumpAndSettle();

      expect(find.text('متأخرة', findRichText: true), findsNothing);
      expect(find.text('اختيار على الخريطة'), findsOneWidget);
    });

    testWidgets('renders the distance on a suggestion row', (tester) async {
      service.canned['مستشفى'] = [
        _suggestion('مستشفى الجامعة', distanceMeters: 2400),
        _suggestion('مستشفى البشير', distanceMeters: 700),
      ];
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'مستشفى');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('2.4 كم'), findsOneWidget);
      expect(find.text('700 م'), findsOneWidget);
    });

    testWidgets('moves focus to the destination after picking an origin', (
      tester,
    ) async {
      service.canned['عمان'] = [_suggestion('وسط البلد')];
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'عمان');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('وسط البلد', findRichText: true));
      await tester.pumpAndSettle();

      // Still on the search screen, now with the origin filled and the
      // destination waiting for input.
      expect(find.byType(RouteSearchScreen), findsOneWidget);
      final origin = tester.widget<TextField>(find.byType(TextField).first);
      expect(origin.controller?.text, 'resolved-وسط البلد');
      final destination = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(destination.focusNode?.hasFocus, isTrue);
    });

    testWidgets('closes with both endpoints after picking a destination', (
      tester,
    ) async {
      service.canned['إربد'] = [_suggestion('شارع الجامعة')];
      final existingOrigin = LocationModel(
        name: 'عمان',
        latitude: 31.9,
        longitude: 35.9,
      );

      RouteSelection? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await Navigator.of(context)
                        .push<RouteSelection>(
                          MaterialPageRoute(
                            builder: (_) => RouteSearchScreen(
                              focusField: RouteField.destination,
                              savedPlaces: savedPlaces,
                              from: existingOrigin,
                              locationService: service,
                            ),
                          ),
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
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'إربد');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شارع الجامعة', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byType(RouteSearchScreen), findsNothing);
      expect(captured?.from?.name, 'عمان');
      expect(captured?.to?.name, 'resolved-شارع الجامعة');
    });

    testWidgets('the keyboard search action never picks a place', (
      tester,
    ) async {
      service.canned['عمان'] = [_suggestion('وسط البلد')];
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'عمان');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Results stay on screen and nothing was selected for the user.
      expect(find.byType(RouteSearchScreen), findsOneWidget);
      final origin = tester.widget<TextField>(find.byType(TextField).first);
      expect(origin.controller?.text, 'عمان');
      expect(find.text('وسط البلد', findRichText: true), findsOneWidget);
    });

    testWidgets('editing after a selection drops the resolved point', (
      tester,
    ) async {
      service.canned['عمان'] = [_suggestion('وسط البلد')];
      final origin = LocationModel(
        name: 'عمان',
        latitude: 31.9,
        longitude: 35.9,
      );

      RouteSelection? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await Navigator.of(context)
                        .push<RouteSelection>(
                          MaterialPageRoute(
                            builder: (_) => RouteSearchScreen(
                              focusField: RouteField.origin,
                              savedPlaces: savedPlaces,
                              from: origin,
                              locationService: service,
                            ),
                          ),
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
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'عم');
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Typed text alone must never travel back as a confirmed point.
      expect(captured, isNotNull);
      expect(captured?.from, isNull);
    });

    testWidgets('offers recent places once one has been confirmed', (
      tester,
    ) async {
      await savedPlaces.addRecent(
        LocationModel(name: 'الجامعة الأردنية', latitude: 32.0, longitude: 35.8),
        secondaryText: 'عمّان',
      );
      await pumpScreen(tester);

      expect(find.text('آخر الأماكن'), findsOneWidget);
      expect(find.text('الجامعة الأردنية', findRichText: true), findsOneWidget);
    });

    testWidgets('the single-point variant asks for one place and closes', (
      tester,
    ) async {
      service.canned['إربد'] = [_suggestion('شارع الجامعة')];

      RouteSelection? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    captured = await Navigator.of(context)
                        .push<RouteSelection>(
                          MaterialPageRoute(
                            builder: (_) => RouteSearchScreen.singlePoint(
                              savedPlaces: savedPlaces,
                              title: 'محطة توقف',
                              locationService: service,
                            ),
                          ),
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
      await tester.pumpAndSettle();

      // A stop has no second endpoint, so only one field is offered.
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'إربد');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شارع الجامعة', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byType(RouteSearchScreen), findsNothing);
      expect(captured?.from?.name, 'resolved-شارع الجامعة');
      expect(captured?.to, isNull);
    });
  });
}
