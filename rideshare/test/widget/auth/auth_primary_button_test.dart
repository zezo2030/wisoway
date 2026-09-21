import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/widgets/auth/auth_primary_button.dart';

Widget _host(TextDirection direction, {bool pinnedArrow = false}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: AuthPrimaryButton(
            label: 'متابعة',
            pinnedArrow: pinnedArrow,
            onPressed: () {},
          ),
        ),
      ),
    );

void main() {
  group('AuthPrimaryButton', () {
    testWidgets('mirrors the arrow with the reading direction by default', (
      tester,
    ) async {
      await tester.pumpWidget(_host(TextDirection.rtl));

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.arrow_back_rounded)).dx,
        lessThan(tester.getCenter(find.text('متابعة')).dx),
      );
    });

    // The driver step-1 mockup draws a right-pointing arrow to the left of the
    // label in Arabic, so [pinnedArrow] has to survive an RTL Directionality.
    testWidgets('pinnedArrow keeps a right arrow left of the label in RTL', (
      tester,
    ) async {
      await tester.pumpWidget(_host(TextDirection.rtl, pinnedArrow: true));

      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(
        tester.getCenter(find.byIcon(Icons.arrow_forward_rounded)).dx,
        lessThan(tester.getCenter(find.text('متابعة')).dx),
      );
      // arrow_forward_rounded has matchTextDirection: true, so picking the
      // IconData is not enough -- the glyph still flips unless it renders
      // under an LTR scope. Assert the scope, not just the code point.
      expect(
        Directionality.of(
          tester.element(find.byIcon(Icons.arrow_forward_rounded)),
        ),
        TextDirection.ltr,
      );
    });

    testWidgets('pinnedArrow renders identically in LTR', (tester) async {
      await tester.pumpWidget(_host(TextDirection.ltr, pinnedArrow: true));

      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.arrow_forward_rounded)).dx,
        lessThan(tester.getCenter(find.text('متابعة')).dx),
      );
    });
  });
}
