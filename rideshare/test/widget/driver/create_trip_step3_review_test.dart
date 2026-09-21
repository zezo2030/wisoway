import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/vehicle_model.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_wizard_state.dart';
import 'package:rideshare/screens/driver/create_trip/step3_review.dart';

/// The review step follows a mockup: the route reads across the summary card
/// instead of down it, the four trip facts sit in one divided strip, and the
/// vehicle photo trails its details. These pin that arrangement, and prove it
/// survives a narrow phone without overflowing.
void main() {
  late CreateTripWizardState wizard;

  VehicleModel vehicleWith({String? imageUrl}) {
    final now = DateTime(2025, 5, 1);
    return VehicleModel(
      id: 'v1',
      driverId: 'd1',
      vehicleType: 'standard_car',
      plateNumber: 'BBR 4445',
      model: 'تويوتا كامري 2025',
      seats: 4,
      carImageUrl: imageUrl,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    wizard = CreateTripWizardState()
      ..from = LocationModel(
        name: 'العلا - حي العزيزية',
        latitude: 26.6,
        longitude: 37.9,
      )
      ..to = LocationModel(
        name: 'المدينة المنورة',
        latitude: 24.4,
        longitude: 39.6,
      )
      ..departureTime = DateTime(2025, 5, 23, 19, 30)
      ..availableSeatCount = 4;
    wizard.priceController.text = '30';
  });

  Future<void> pumpReview(
    WidgetTester tester, {
    Size size = const Size(360, 2200),
    VehicleModel? vehicle,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Step3Review(
            wizard: wizard,
            vehicle: vehicle,
            currency: 'ريال',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Step3Review', () {
    testWidgets('names each section the way the review mockup does', (
      tester,
    ) async {
      await pumpReview(tester, vehicle: vehicleWith());

      expect(find.text('ملخص الرحلة'), findsOneWidget);
      expect(find.text('تفاصيل إضافية'), findsOneWidget);
      expect(find.text('المركبة'), findsOneWidget);
    });

    testWidgets('runs the route across the card, origin on the start side', (
      tester,
    ) async {
      await pumpReview(tester);

      final from = tester.getCenter(find.text('العلا - حي العزيزية'));
      final to = tester.getCenter(find.text('المدينة المنورة'));

      // One line, not a vertical stack.
      expect(from.dy, closeTo(to.dy, 1));
      // Arabic reads right to left, so the origin sits to the right.
      expect(from.dx, greaterThan(to.dx));
    });

    testWidgets('lines the four trip facts up in one strip', (tester) async {
      await pumpReview(tester);

      final labels = ['التاريخ', 'وقت الانطلاق', 'المقاعد المتاحة'];
      final centres = labels
          .map((label) => tester.getCenter(find.text(label)))
          .toList();

      for (final centre in centres) {
        expect(centre.dy, closeTo(centres.first.dy, 1));
      }
      // Right to left, in the mockup's order.
      expect(centres[0].dx, greaterThan(centres[1].dx));
      expect(centres[1].dx, greaterThan(centres[2].dx));

      expect(find.text('4 مقعد'), findsOneWidget);
      expect(find.text('30.00 ريال'), findsOneWidget);
    });

    testWidgets('trails the vehicle photo behind its details', (tester) async {
      await pumpReview(tester, vehicle: vehicleWith());

      final model = tester.getCenter(find.text('تويوتا كامري 2025'));
      final plate = tester.getCenter(find.text('BBR 4445'));
      final photo = tester.getCenter(find.byType(ClipRRect).last);

      // Details on the reading side, photo on the far side.
      expect(model.dx, greaterThan(photo.dx));
      expect(plate.dx, greaterThan(photo.dx));
    });

    testWidgets('closes with a titled publish notice', (tester) async {
      await pumpReview(tester);

      expect(find.text('الرحلة ستنتشر بعد المراجعة'), findsOneWidget);
      expect(
        find.text('بمجرد نشر الرحلة سيتمكن الركاب من حجز المقاعد المتاحة'),
        findsOneWidget,
      );
    });

    testWidgets('lists each note line on its own row', (tester) async {
      wizard.notesController.text =
          'التدخين ممنوع داخل السيارة\nيرجى التواصل قبل 5 دقائق';
      await pumpReview(tester);

      expect(find.text('ملاحظات للركاب'), findsOneWidget);
      expect(find.text('التدخين ممنوع داخل السيارة'), findsOneWidget);
      expect(find.text('يرجى التواصل قبل 5 دقائق'), findsOneWidget);
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      // A long Arabic date in a quarter-width cell is the tightest case.
      await pumpReview(
        tester,
        size: const Size(320, 2400),
        vehicle: vehicleWith(),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
