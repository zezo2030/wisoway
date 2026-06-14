import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';
import 'package:rideshare/screens/settings/account_security_screen.dart';

Widget _createTestWidget() {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: LocalizationService())],
    child: MaterialApp(home: const AccountSecurityScreen()),
  );
}

void main() {
  group('Account Security Screen', () {
    testWidgets('renders loading state when no user data', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders app bar title', (tester) async {
      await tester.pumpWidget(_createTestWidget());
      await tester.pump();

      expect(find.text('الحساب والأمان'), findsOneWidget);
    });
  });
}
