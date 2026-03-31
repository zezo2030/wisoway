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

  group('Dark Mode Toggle', () {
    testWidgets('dark mode switch is visible in Appearance section', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('الوضع الداكن'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('toggling dark mode switch changes theme to dark', (
      tester,
    ) async {
      final themeService = ThemeService();
      await tester.pumpWidget(_createTestWidget(themeService: themeService));
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsWidgets);

      Switch toggle = tester.widget(switchFinder.first);
      expect(toggle.value, themeService.themeMode == ThemeMode.dark);

      await tester.tap(switchFinder.first);
      await tester.pump();

      expect(themeService.themeMode, ThemeMode.dark);
    });

    testWidgets('toggling dark mode off changes theme to light', (
      tester,
    ) async {
      final themeService = ThemeService();
      await themeService.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(_createTestWidget(themeService: themeService));
      await tester.pump();

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder.first);
      await tester.pump();

      expect(themeService.themeMode, ThemeMode.light);
    });
  });

  group('Theme Mode Selector Bottom Sheet', () {
    testWidgets('tapping theme mode tile opens bottom sheet', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      final themeTile = find.text('سمة التطبيق');
      expect(themeTile, findsOneWidget);

      await tester.tap(themeTile);
      await tester.pump();

      expect(find.text('اختر السمة'), findsOneWidget);
      expect(find.text('تلقائي (حسب النظام)'), findsOneWidget);
      expect(find.text('فاتح'), findsOneWidget);
      expect(find.text('داكن'), findsOneWidget);
    });

    testWidgets('selecting a theme mode updates the service', (tester) async {
      final themeService = ThemeService();
      await tester.pumpWidget(_createTestWidget(themeService: themeService));
      await tester.pump();

      await tester.tap(find.text('سمة التطبيق'));
      await tester.pump();

      await tester.tap(find.text('داكن'));
      await tester.pump();

      expect(themeService.themeMode, ThemeMode.dark);
    });
  });
}
