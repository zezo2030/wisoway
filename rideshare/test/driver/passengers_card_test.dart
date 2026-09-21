import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/booking_model.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/screens/driver/widgets/passengers_card.dart';

void main() {
  testWidgets('passenger name and phone show without payment',
      (tester) async {
    final now = DateTime.now();
    final booking = BookingModel(
      id: 'b-1',
      tripId: 't-1',
      userId: 'u-1',
      hasDriverPaidToContact: false,
      sharePhoneWithDriver: true,
      seatNumber: 'A1',
      status: 'confirmed',
      createdAt: now,
      updatedAt: now,
      userPopulated: UserModel(
        id: 'u-1',
        phoneNumber: '0790000000',
        email: 'ahmad@example.com',
        name: 'أحمد محمود',
        gender: 'male',
        role: 'passenger',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: PassengersCard(bookings: [booking])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أحمد محمود'), findsOneWidget);
    expect(find.byIcon(IconsaxPlusLinear.call), findsOneWidget);
  });
}
