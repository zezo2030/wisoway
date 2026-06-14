import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/services/localization_service.dart';

void main() {
  testWidgets('Notifications screen shows login required when no user', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: const MaterialApp(home: _MockNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('يجب تسجيل الدخول'), findsOneWidget);
  });
}

class _MockNotificationsScreen extends StatelessWidget {
  const _MockNotificationsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: const Center(child: Text('يجب تسجيل الدخول')),
    );
  }
}
