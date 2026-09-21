import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/widgets/auth/auth_language_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthLanguageSwitcher', () {
    testWidgets('renders the pill with the active language', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocalizationService(),
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AuthLanguageSwitcher()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('العربية'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('offers both languages when opened', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocalizationService(),
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AuthLanguageSwitcher()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
    });
  });
}
