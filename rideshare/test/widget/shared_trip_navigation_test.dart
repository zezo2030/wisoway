import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/core/errors/failure.dart';
import 'package:rideshare/core/navigation/shared_trip_navigation.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';

void main() {
  Future<void> host(WidgetTester tester, Future<void> Function() check) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          RouteNames.createTrip: (_) => const Scaffold(body: Text('TRIP_FORM')),
          RouteNames.driverWalletTopup: (_) =>
              const Scaffold(body: Text('TOPUP')),
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  SharedTripNavigation.open(context, checkEligibility: check),
              child: const Text('PUBLISH'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('checks before showing the form and waits for server approval', (
    tester,
  ) async {
    final ready = Completer<void>();
    await host(tester, () => ready.future);
    await tester.tap(find.text('PUBLISH'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('TRIP_FORM'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('TRIP_FORM'), findsOneWidget);
  });

  testWidgets('empty wallet stays outside and offers top-up', (tester) async {
    await host(
      tester,
      () async => throw const Failure(
        category: FailureCategory.permission,
        messageKey: 'errorsNegativeWalletBalance',
        displayMessage: 'TOP_UP_REQUIRED',
        severity: FailureSeverity.error,
        nextAction: FailureAction.topUpWallet,
        developerDetail: 'empty wallet',
      ),
    );
    await tester.tap(find.text('PUBLISH'));
    await tester.pumpAndSettle();
    expect(find.text('TRIP_FORM'), findsNothing);
    expect(find.text('TOP_UP_REQUIRED'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('TOPUP'), findsOneWidget);
  });

  testWidgets('failed connection does not bypass the check', (tester) async {
    await host(tester, () async => throw Exception('offline'));
    await tester.tap(find.text('PUBLISH'));
    await tester.pumpAndSettle();
    expect(find.text('TRIP_FORM'), findsNothing);
  });
}
