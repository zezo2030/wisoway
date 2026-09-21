import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rideshare/core/services/error_localizations.dart';

/// Regression coverage for the ErrorLocalizations dictionaries themselves —
/// independent of ErrorSurface — so a missing entry is caught even if it's
/// never routed through the generic error dialog in a given test run.
///
/// `ErrorLocalizations.resolve` falls back `map[key] ?? _en[key] ?? key`, so
/// a naive "isn't the raw key" assertion wouldn't catch a *single*-locale
/// removal (Arabic missing would silently fall back to the English text).
/// Each case below asserts language-specific wording instead.
void main() {
  group('ErrorLocalizations', () {
    Future<String> resolveIn(
      WidgetTester tester,
      String key,
      TextDirection direction,
    ) async {
      late String resolved;
      await tester.pumpWidget(
        Localizations(
          // The locale drives the copy; direction only mirrors the layout.
          locale: direction == TextDirection.rtl
              ? const Locale('ar')
              : const Locale('en'),
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Directionality(
          textDirection: direction,
          child: Builder(
            builder: (context) {
              resolved = ErrorLocalizations.resolve(context, key);
              return const SizedBox.shrink();
            },
          ),
          ),
        ),
      );
      return resolved;
    }

    testWidgets(
      'errorsInsufficientBalanceForTripFee resolves to real English copy, '
      'not the raw messageKey',
      (tester) async {
        final message = await resolveIn(
          tester,
          'errorsInsufficientBalanceForTripFee',
          TextDirection.ltr,
        );

        expect(message, isNot('errorsInsufficientBalanceForTripFee'));
        expect(message, contains('trip fee'));
      },
    );

    testWidgets(
      'errorsInsufficientBalanceForTripFee resolves to real Arabic copy, '
      'not the raw messageKey and not an English fallback',
      (tester) async {
        final message = await resolveIn(
          tester,
          'errorsInsufficientBalanceForTripFee',
          TextDirection.rtl,
        );

        expect(message, isNot('errorsInsufficientBalanceForTripFee'));
        expect(message, contains('رسوم الرحلة'));
      },
    );

    // Pre-existing entry (the NEGATIVE_WALLET_BALANCE precedent that the
    // INSUFFICIENT_BALANCE_FOR_TRIP_FEE mapping followed). Guarded here too
    // so it can't silently regress the same way.
    testWidgets(
      'errorsNegativeWalletBalance resolves to real copy in both locales',
      (tester) async {
        final en = await resolveIn(
          tester,
          'errorsNegativeWalletBalance',
          TextDirection.ltr,
        );
        final ar = await resolveIn(
          tester,
          'errorsNegativeWalletBalance',
          TextDirection.rtl,
        );

        expect(en, isNot('errorsNegativeWalletBalance'));
        expect(en, contains('negative'));
        expect(ar, isNot('errorsNegativeWalletBalance'));
        expect(ar, contains('سالب'));
      },
    );
  });
}
