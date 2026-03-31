import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideshare/core/services/theme_service.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/screens/settings/settings_screen.dart';

Widget _createTestWidget({
  ThemeService? themeService,
  LocalizationService? localizationService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeService ?? ThemeService()),
      ChangeNotifierProvider.value(
        value: localizationService ?? LocalizationService(),
      ),
    ],
    child: MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: const SettingsScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Language Selector Flow', () {
    testWidgets('language section is visible with current language label', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('اللغة'), findsAtLeast(1));
    });

    testWidgets('tapping language tile opens bottom sheet with options', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      await tester.tap(find.text('اللغة').first);
      await tester.pump();

      expect(find.text('اختر اللغة'), findsOneWidget);
      expect(find.text('العربية'), findsWidgets);
      expect(find.text('English'), findsWidgets);
    });

    testWidgets('selecting English changes language in service', (
      tester,
    ) async {
      final locService = LocalizationService();
      await tester.pumpWidget(
        _createTestWidget(localizationService: locService),
      );
      await tester.pump();

      await tester.tap(find.text('اللغة').first);
      await tester.pump();

      final englishOptions = find.text('English');
      await tester.tap(englishOptions.first);
      await tester.pump();

      expect(locService.locale.languageCode, 'en');
      expect(locService.isArabic, isFalse);
    });
  });

  group('RTL/LTR Direction Change', () {
    testWidgets('Arabic locale shows Arabic settings title', (tester) async {
      final locService = LocalizationService();
      await tester.pumpWidget(
        _createTestWidget(localizationService: locService),
      );
      await tester.pump();

      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('switching to English updates UI text', (tester) async {
      final locService = LocalizationService();
      await tester.pumpWidget(
        _createTestWidget(localizationService: locService),
      );
      await tester.pump();

      expect(find.text('الإعدادات'), findsOneWidget);

      await locService.setLanguage('en');
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Language'), findsAtLeast(1));
    });
  });
}
