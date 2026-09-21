import 'package:flutter/material.dart';
// RenderParagraph lives here, not in material.dart — the truncation checks
// read it straight off the laid-out text.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_stepper.dart';

/// The shared text styles bake a dark colour into every level, so a label
/// dropped on the brand-coloured button inherits that colour instead of the
/// button's own foreground. These lock the forward action to `onPrimary` in
/// both themes, which is white on the light teal button.
void main() {
  Future<void> pumpFooter(
    WidgetTester tester, {
    required ThemeData theme,
    bool enabled = true,
    bool busy = false,
    String backLabel = 'السابق',
    String forwardLabel = 'التالي',
    double width = 390,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CreateTripFooter(
              showBack: true,
              backLabel: backLabel,
              forwardLabel: forwardLabel,
              forwardIcon: Icons.chevron_right_rounded,
              busy: busy,
              onBack: () {},
              onForward: enabled ? () {} : null,
            ),
          ),
        ),
      ),
    );
    // A spinner never settles, so a busy footer only gets a single frame.
    if (busy) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Color? labelColor(WidgetTester tester, String label) {
    return tester.widget<Text>(find.text(label)).style?.color;
  }

  group('CreateTripFooter', () {
    testWidgets('writes the forward label in the on-primary colour', (
      tester,
    ) async {
      final theme = AppTheme.lightTheme;
      await pumpFooter(tester, theme: theme);

      expect(labelColor(tester, 'التالي'), theme.colorScheme.onPrimary);
    });

    testWidgets('keeps the label readable in the dark theme too', (
      tester,
    ) async {
      final theme = AppTheme.darkTheme;
      await pumpFooter(tester, theme: theme);

      expect(labelColor(tester, 'التالي'), theme.colorScheme.onPrimary);
    });

    testWidgets('dims the label rather than darkening it when disabled', (
      tester,
    ) async {
      final theme = AppTheme.lightTheme;
      await pumpFooter(tester, theme: theme, enabled: false);

      final color = labelColor(tester, 'التالي');
      expect(color?.withValues(alpha: 1), theme.colorScheme.onPrimary);
      expect(color?.a, lessThan(1.0));
    });

    testWidgets('spins in the same colour as the label', (tester) async {
      final theme = AppTheme.lightTheme;
      await pumpFooter(tester, theme: theme, busy: true);

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, theme.colorScheme.onPrimary);
    });

    testWidgets('leaves the back button on its outlined treatment', (
      tester,
    ) async {
      final theme = AppTheme.lightTheme;
      await pumpFooter(tester, theme: theme);

      expect(labelColor(tester, 'السابق'), theme.colorScheme.primary);
    });

    /// The review step pairs a long back label with a short forward one. A
    /// fixed width share clipped it to "العودة للت…", which reads as a
    /// different action.
    for (final width in <double>[320, 360, 390, 430]) {
      testWidgets('never clips the review labels at ${width.toInt()}dp', (
        tester,
      ) async {
        await pumpFooter(
          tester,
          theme: AppTheme.lightTheme,
          backLabel: 'العودة للتعديل',
          forwardLabel: 'نشر الرحلة',
          width: width,
        );

        for (final label in ['العودة للتعديل', 'نشر الرحلة']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '"$label" was truncated at ${width.toInt()}dp',
          );
        }

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the publish button the wider of the two', (
      tester,
    ) async {
      await pumpFooter(
        tester,
        theme: AppTheme.lightTheme,
        backLabel: 'العودة للتعديل',
        forwardLabel: 'نشر الرحلة',
      );

      final back = tester.getSize(find.byType(OutlinedButton)).width;
      final forward = tester.getSize(find.byType(ElevatedButton)).width;

      expect(forward, greaterThan(back));
    });
  });
}
