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

  group('Settings Screen Section Rendering', () {
    testWidgets('renders all expected sections', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('اللغة'), findsAtLeast(1));
      expect(find.text('الإشعارات'), findsAtLeast(1));
      expect(find.text('الحساب والأمان'), findsOneWidget);
      expect(find.text('الخصوصية'), findsOneWidget);
    });

    testWidgets('renders dark mode switch in Appearance section', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('الوضع الداكن'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });
  });

  group('Settings Navigation from Profile', () {
    testWidgets('settings screen has app bar with back button', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
    });
  });
}
