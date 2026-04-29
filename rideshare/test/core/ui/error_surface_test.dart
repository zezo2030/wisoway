import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideshare/core/errors/failure.dart';
import 'package:rideshare/core/ui/error_surface.dart';

void main() {
  group('ErrorSurface.showFailure', () {
    Widget buildTestApp({
      required Failure failure,
      VoidCallback? onRetry,
      TextDirection textDirection = TextDirection.rtl,
    }) {
      return MaterialApp(
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ErrorSurface.showFailure(
                      context,
                      failure,
                      onRetry: onRetry,
                    );
                  },
                  child: const Text('Trigger Error'),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('warning severity shows SnackBar with localized Arabic message',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.warning,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.rtl,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('أنت غير متصل بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.'),
        findsOneWidget,
      );
    });

    testWidgets('warning severity shows SnackBar with localized English message',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.warning,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.ltr,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text("You're offline. Check your connection and try again."),
        findsOneWidget,
      );
    });

    testWidgets('info severity shows SnackBar', (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.info,
          developerDetail: 'test detail',
        ),
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
        'error severity shows Dialog with localized Arabic message and title',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.server,
          messageKey: 'errorsServerGeneric',
          severity: FailureSeverity.error,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.rtl,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('خطأ'), findsOneWidget);
      expect(
        find.text('حدث خطأ في الخادم. حاول مرة أخرى لاحقاً.'),
        findsOneWidget,
      );
      expect(find.text('موافق'), findsOneWidget);
    });

    testWidgets(
        'error severity shows Dialog with localized English message and title',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.server,
          messageKey: 'errorsServerGeneric',
          severity: FailureSeverity.error,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.ltr,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text('Something went wrong on our end. Please try again later.'),
        findsOneWidget,
      );
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets(
        'error severity with reauthenticate action shows action button in dialog',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.auth,
          messageKey: 'errorsAuthSessionExpired',
          severity: FailureSeverity.error,
          nextAction: FailureAction.reauthenticate,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.rtl,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('خطأ'), findsOneWidget);
      expect(
        find.text('انتهت صلاحية جلستك. يرجى تسجيل الدخول مرة أخرى.'),
        findsOneWidget,
      );
      expect(find.text('تسجيل الدخول مرة أخرى'), findsOneWidget);
    });

    testWidgets('warning with retry action shows SnackBar with action',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.warning,
          nextAction: FailureAction.retry,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.rtl,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('retry action calls onRetry callback', (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.network,
          messageKey: 'errorsNetworkOffline',
          severity: FailureSeverity.warning,
          nextAction: FailureAction.retry,
          developerDetail: 'test detail',
        ),
        onRetry: () => retryCalled = true,
        textDirection: TextDirection.ltr,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      expect(retryCalled, isTrue);
    });

    testWidgets('reauthenticate action navigates to sign-in', (tester) async {
      await tester.pumpWidget(MaterialApp(
        routes: {
          '/': (context) => Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () {
                          ErrorSurface.showFailure(
                            context,
                            const Failure(
                              category: FailureCategory.auth,
                              messageKey: 'errorsAuthSessionExpired',
                              severity: FailureSeverity.error,
                              nextAction: FailureAction.reauthenticate,
                              developerDetail: 'test detail',
                            ),
                          );
                        },
                        child: const Text('Trigger Auth Error'),
                      );
                    },
                  ),
                ),
              ),
          '/sign-in': (context) => const Scaffold(
                body: Text('Sign In Screen'),
              ),
        },
      ));

      await tester.tap(find.text('Trigger Auth Error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In Screen'), findsOneWidget);
    });

    testWidgets('openSettings action label is localized', (tester) async {
      await tester.pumpWidget(buildTestApp(
        failure: const Failure(
          category: FailureCategory.permission,
          messageKey: 'errorsPermissionDenied',
          severity: FailureSeverity.error,
          nextAction: FailureAction.openSettings,
          developerDetail: 'test detail',
        ),
        textDirection: TextDirection.ltr,
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Permission denied. Check your app settings.'),
          findsOneWidget);
    });
  });
}
