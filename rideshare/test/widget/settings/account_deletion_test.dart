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

  group('Account Deletion Flow', () {
    testWidgets('delete account tile triggers first confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('حذف الحساب'),
        listFinder,
        const Offset(0, -500),
      );

      expect(find.text('حذف الحساب'), findsOneWidget);

      await tester.tap(find.text('حذف الحساب'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'هل أنت متأكد من رغبتك في حذف حسابك؟ هذا الإجراء لا يمكن التراجع عنه.',
        ),
        findsOneWidget,
      );
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('نعم، حذف الحساب'), findsOneWidget);
    });

    testWidgets('cancelling first dialog returns to settings screen', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('حذف الحساب'),
        listFinder,
        const Offset(0, -500),
      );

      await tester.tap(find.text('حذف الحساب'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('confirming first dialog shows second confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('حذف الحساب'),
        listFinder,
        const Offset(0, -500),
      );

      await tester.tap(find.text('حذف الحساب'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('نعم، حذف الحساب'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'تحذير أخير: سيتم حذف جميع بياناتك بشكل نهائي ولن تتمكن من استرجاعها.',
        ),
        findsOneWidget,
      );
      expect(find.text('حذف نهائي'), findsOneWidget);
    });

    testWidgets('backend failure shows contact support dialog', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('حذف الحساب'),
        listFinder,
        const Offset(0, -500),
      );

      await tester.tap(find.text('حذف الحساب'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('نعم، حذف الحساب'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('حذف نهائي'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('تواصل مع الدعم'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
    });
  });
}
