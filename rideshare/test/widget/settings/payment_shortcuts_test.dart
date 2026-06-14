import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/core/services/theme_service.dart';
import 'package:rideshare/screens/settings/settings_screen.dart';

Widget _createTestWidget() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: ThemeService()),
      ChangeNotifierProvider.value(value: LocalizationService()),
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

  group('Payment & Wallet Shortcuts', () {
    testWidgets('wallet and payment history tiles are visible', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('المحفظة'),
        listFinder,
        const Offset(0, -500),
      );

      expect(find.text('المحفظة'), findsOneWidget);
      expect(find.text('سجل المدفوعات'), findsOneWidget);
    });
  });
}
