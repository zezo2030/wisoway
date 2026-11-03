import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/screens/settings/about_screen.dart';

Widget _createTestWidget() {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: LocalizationService())],
    child: const MaterialApp(home: AboutScreen()),
  );
}

void main() {
  group('About Screen', () {
    testWidgets('renders app metadata', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('RideShare'), findsOneWidget);
      expect(find.text('منصة مشاركة الرحلات'), findsOneWidget);
    });

    testWidgets('renders action tiles', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('تقييم التطبيق'), findsOneWidget);
      expect(find.text('مشاركة التطبيق'), findsOneWidget);
      expect(find.text('التراخيص'), findsOneWidget);
    });
  });
}
