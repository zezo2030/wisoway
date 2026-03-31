import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/core/services/settings_service.dart';
import 'package:rideshare/screens/settings/notification_settings_screen.dart';

Widget _createTestWidget() {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: LocalizationService())],
    child: MaterialApp(home: NotificationSettingsScreen()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notification Settings', () {
    testWidgets('renders notification category toggles', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('الرحلات'), findsOneWidget);
      expect(find.text('المدفوعات'), findsOneWidget);
      expect(find.text('الرسائل'), findsOneWidget);
      expect(find.text('النظام'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('tapping a category switch changes its value', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      await tester.tap(switches.first);
      await tester.pump();
    });
  });
}
