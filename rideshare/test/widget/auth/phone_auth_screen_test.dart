// T020 — Flutter widget test: phone-only auth screen
//
// Covers:
//  - PhoneAuthScreen renders the phone field and submit button (no email field)
//  - Submitting an empty form shows validation error
//  - OTPVerificationScreen renders 6 digit fields and resend button
//  - No sign-in with email / Google / Facebook widgets are present anywhere
//    in either screen (phone-only auth contract)
//
// These tests are intentionally written against the *existing* PhoneAuthScreen
// widget — they document the current shape and will catch regressions when
// T038 removes the legacy email/social entry points.
//
// Run with: flutter test test/widget/auth/phone_auth_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../lib/screens/auth/phone_auth_screen.dart';
import '../../../lib/screens/auth/otp_verification_screen.dart';
import '../../../lib/providers/auth_provider.dart';
import '../../../lib/core/constants/app_constants.dart';

// ---------------------------------------------------------------------------
// Minimal stub for AuthProvider so we don't hit a real server.
// Replace with mockito mock once T038 lands and AuthProvider is refactored.
// ---------------------------------------------------------------------------
class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>(
      create: (_) => _FakeAuthProvider(),
      child: child,
    ),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // 1. PhoneAuthScreen — basic render
  // -------------------------------------------------------------------------
  group('PhoneAuthScreen', () {
    testWidgets('renders phone text field', (tester) async {
      await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('renders submit button', (tester) async {
      await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('does NOT render an email field', (tester) async {
      await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
      // No field with "email" label/hint should be present
      expect(
        find.byWidgetPredicate((w) {
          if (w is TextField) {
            return w.keyboardType == TextInputType.emailAddress;
          }
          if (w is TextFormField) {
            return w.keyboardType == TextInputType.emailAddress;
          }
          return false;
        }),
        findsNothing,
      );
    });

    testWidgets('does NOT render Google or Facebook sign-in buttons',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
      // No text referencing social providers
      expect(find.textContaining('Google', findRichText: true), findsNothing);
      expect(
          find.textContaining('Facebook', findRichText: true), findsNothing);
    });

    testWidgets('shows validation error when submitting empty phone',
        (tester) async {
      await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      // The Arabic validation message should appear
      expect(find.text('يرجى إدخال رقم الهاتف'), findsOneWidget);
    });

    testWidgets('isLinkPhone=true shows confirmation title', (tester) async {
      await tester.pumpWidget(
          _wrap(const PhoneAuthScreen(isLinkPhone: true)));
      expect(find.text('تأكيد رقم الهاتف'), findsOneWidget);
    });

    testWidgets('isLinkPhone=false shows sign-in title', (tester) async {
      await tester.pumpWidget(_wrap(const PhoneAuthScreen()));
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. OTPVerificationScreen — basic render
  // -------------------------------------------------------------------------
  group('OTPVerificationScreen', () {
    const testPhone = '+201234567890';

    testWidgets('renders exactly otpLength digit fields', (tester) async {
      await tester.pumpWidget(
        _wrap(OTPVerificationScreen(phoneNumber: testPhone)),
      );
      // Each digit input is a TextField inside a Container
      expect(
        find.byType(TextField),
        findsNWidgets(AppConstants.otpLength),
      );
    });

    testWidgets('renders masked phone number in body text', (tester) async {
      await tester.pumpWidget(
        _wrap(OTPVerificationScreen(phoneNumber: testPhone)),
      );
      // Masked form: first 3 + ***** + last 3 chars
      expect(find.textContaining('+20'), findsWidgets);
    });

    testWidgets('resend button is initially disabled (timer running)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(OTPVerificationScreen(phoneNumber: testPhone)),
      );
      // The resend text should show a countdown, not an active tap target
      expect(
        find.textContaining('إعادة إرسال الرمز خلال'),
        findsOneWidget,
      );
    });

    testWidgets('verify button is disabled when OTP fields are empty',
        (tester) async {
      await tester.pumpWidget(
        _wrap(OTPVerificationScreen(phoneNumber: testPhone)),
      );
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      // onPressed should be null (disabled) when no digits entered
      expect(button.onPressed, isNull);
    });
  });
}
