import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/screens/auth/driver_sign_up_screen.dart';
import 'package:rideshare/screens/auth/sign_up_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2424);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectEmailRequired(WidgetTester tester) async {
    final field = find.text('البريد الإلكتروني');
    expect(field, findsOneWidget);

    expect(
      tester.state<FormState>(find.byType(Form).first).validate(),
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(find.text('بريد إلكتروني غير صحيح'), findsOneWidget);
  }

  testWidgets('a passenger cannot sign up without an email', (tester) async {
    await pump(tester, const SignUpScreen());
    await expectEmailRequired(tester);
  });

  testWidgets('a driver cannot sign up without an email', (tester) async {
    await pump(tester, const DriverSignUpScreen());
    await expectEmailRequired(tester);
  });
}
