import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/providers/auth_provider.dart';
import '../../support/fake_auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/settings/privacy_settings_screen.dart';

Widget _createTestWidget() {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: LocalizationService())],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const PrivacySettingsScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Privacy Settings', () {
    testWidgets('renders all three privacy toggles', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('مشاركة الموقع'), findsOneWidget);
      expect(find.text('الظهور متصل'), findsOneWidget);
      expect(find.text('إظهار التقييم'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('toggling location sharing switch works', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pump();
    });

    testWidgets('shows privacy info text at bottom', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('هذه الإعدادات تتحكم في ما يمكن للآخرين رؤيته عنك'),
        findsOneWidget,
      );
    });
  });
}
