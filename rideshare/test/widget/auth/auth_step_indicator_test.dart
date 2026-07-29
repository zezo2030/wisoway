import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/widgets/auth/auth_step_indicator.dart';

void main() {
  group('AuthStepIndicator', () {
    testWidgets('highlights current step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthStepIndicator(currentStep: 2, totalSteps: 3),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('earlier steps become checks, later steps keep numbers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthStepIndicator(currentStep: 2, totalSteps: 3),
          ),
        ),
      );

      // Step 1 is done → rendered as a check, not the digit "1".
      expect(find.text('1'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders one caption per step when labels are given', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthStepIndicator(
              currentStep: 1,
              totalSteps: 3,
              labels: ['Basic', 'Documents', 'Vehicle'],
            ),
          ),
        ),
      );

      expect(find.text('Basic'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Vehicle'), findsOneWidget);
    });
  });
}
