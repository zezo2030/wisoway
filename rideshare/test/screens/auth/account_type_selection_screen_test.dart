import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/constants/route_names.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/auth/account_type_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

Future<void> _pumpFromWelcome(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LocalizationService(),
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          '/': (_) => Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    RouteNames.accountTypeSelection,
                  ),
                  child: const Text('welcome'),
                ),
              ),
            ),
          ),
          RouteNames.accountTypeSelection: (_) =>
              const AccountTypeSelectionScreen(),
          RouteNames.signUp: (_) => _stub('passenger sign-up'),
          RouteNames.driverSignUp: (_) => _stub('driver sign-up'),
        },
      ),
    ),
  );
  await tester.tap(find.text('welcome'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('back from passenger sign-up returns to account type, '
      'not the first screen', (tester) async {
    await _pumpFromWelcome(tester);

    await tester.tap(find.text('راكب'));
    await tester.pumpAndSettle();
    expect(find.text('passenger sign-up'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(AccountTypeSelectionScreen), findsOneWidget);
    expect(find.text('welcome'), findsNothing);
  });

  testWidgets(
    'shared rides read "share the ride with others"; no safety card',
    (tester) async {
      await _pumpFromWelcome(tester);

      expect(find.text('شارك الرحلة مع أفراد آخرين'), findsOneWidget);
      expect(find.text('أمانك هو أولويتنا'), findsNothing);
      expect(find.textContaining('لديك حساب بالفعل'), findsOneWidget);
    },
  );

  testWidgets('fits a small phone without scrolling', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpFromWelcome(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsNothing);
    final signIn = tester.getRect(find.textContaining('لديك حساب بالفعل'));
    expect(signIn.bottom, lessThanOrEqualTo(640));
  });
}
