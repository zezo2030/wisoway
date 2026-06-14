import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/screens/settings/privacy_settings_screen.dart';

Widget _createTestWidget() {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: LocalizationService())],
    child: MaterialApp(home: const PrivacySettingsScreen()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Privacy Settings', () {
    testWidgets('renders all three privacy toggles', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('مشاركة الموقع'), findsOneWidget);
      expect(find.text('الظهور متصل'), findsOneWidget);
      expect(find.text('إظهار التقييم'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('toggling location sharing switch works', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pump();
    });

    testWidgets('shows privacy info text at bottom', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(
        find.text('هذه الإعدادات تتحكم في ما يمكن للآخرين رؤيته عنك'),
        findsOneWidget,
      );
    });
  });
}
