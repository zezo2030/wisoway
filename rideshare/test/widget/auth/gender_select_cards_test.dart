import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/constants/app_constants.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/widgets/auth/gender_select_cards.dart';

Widget _host(Locale locale, {String? value, String? label}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: GenderSelectCards(label: label, value: value, onChanged: (_) {}),
  ),
);

void main() {
  group('GenderSelectCards', () {
    testWidgets('renders the caption with the asterisk in the error colour', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const Locale('en'), label: 'Gender *'));

      final caption = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      final spans = (caption.textSpan! as TextSpan).children!.cast<TextSpan>();

      expect(spans.first.text, 'Gender ');
      expect(spans.last.text, '*');
      expect(spans.last.style!.color, isNot(spans.first.style?.color));
    });

    testWidgets('uses the venus/mars glyphs from the mockup', (tester) async {
      await tester.pumpWidget(_host(const Locale('ar')));

      expect(find.byIcon(Icons.female), findsOneWidget);
      expect(find.byIcon(Icons.male), findsOneWidget);
    });

    // The mockup pins the card order and the badge corner physically, so they
    // must not flip with the reading direction.
    for (final locale in const [Locale('ar'), Locale('en')]) {
      final code = locale.languageCode;

      testWidgets('keeps male on the physical right in $code', (tester) async {
        await tester.pumpWidget(_host(locale));

        expect(
          tester.getCenter(find.byIcon(Icons.male)).dx,
          greaterThan(tester.getCenter(find.byIcon(Icons.female)).dx),
        );
      });

      // The compact card closes with the tick, so unlike the pair's ordering
      // this one does follow the reading direction.
      testWidgets('closes the selected card with the tick in $code', (
        tester,
      ) async {
        await tester.pumpWidget(_host(locale, value: AppConstants.genderMale));

        final tick = tester.getCenter(find.byIcon(Icons.check)).dx;
        final glyph = tester.getCenter(find.byIcon(Icons.male)).dx;

        expect(
          locale.languageCode == 'ar' ? tick < glyph : tick > glyph,
          isTrue,
        );
      });
    }
  });
}
