import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/screens/auth/sign_in_screen.dart';
import 'package:rideshare/widgets/common/form_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no feature badges; "new user" sits right under sign in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalizationService()),
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
          // The test font is far wider than Tajawal; scale it down so the
          // layout stays representative.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.6)),
            child: child!,
          ),
          home: const SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final removed in ['موثوق ومعتمد', 'سريع وسهل', 'أمان وخصوصية']) {
      expect(find.text(removed), findsNothing);
    }

    final button = tester.getRect(find.byType(PrimaryGradientButton));
    final newUser = tester.getRect(find.textContaining('مستخدم جديد'));
    expect(newUser.top, greaterThan(button.bottom));
    // Directly below: only the 12 px gap and the bar's own padding between.
    expect(newUser.top - button.bottom, lessThan(40));
  });
}
