import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations_ar.dart';
import 'package:rideshare/l10n/generated/app_localizations_en.dart';
import 'package:rideshare/models/vehicle_colors.dart';

void main() {
  group('vehicle colours', () {
    test('a stored key reads in the viewer language', () {
      expect(vehicleColorLabel(AppLocalizationsAr(), 'white'), 'أبيض');
      expect(vehicleColorLabel(AppLocalizationsEn(), 'white'), 'White');
    });

    test('an old free-text name still maps to its colour', () {
      expect(vehicleColorFor('أبيض')?.key, 'white');
      expect(vehicleColorFor(' Grey ')?.key, 'gray');
      expect(vehicleColorLabel(AppLocalizationsEn(), 'فضي'), 'Silver');
    });

    test('an unknown value is shown as it was typed', () {
      expect(vehicleColorFor('لؤلؤي'), isNull);
      expect(vehicleColorLabel(AppLocalizationsEn(), 'لؤلؤي'), 'لؤلؤي');
    });

    test('every listed colour has a name in both languages', () {
      for (final option in kVehicleColors) {
        expect(vehicleColorName(AppLocalizationsAr(), option.key),
            isNot(option.key));
        expect(vehicleColorName(AppLocalizationsEn(), option.key),
            isNot(option.key));
      }
    });
  });
}
