import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/screens/home/widgets/passenger_avatar_stack.dart';

Widget _host({
  required List<String> avatars,
  required int totalPassengers,
  Locale locale = const Locale('ar'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: PassengerAvatarStack(
      avatars: avatars,
      totalPassengers: totalPassengers,
    ),
  ),
);

void main() {
  group('PassengerAvatarStack', () {
    testWidgets('draws one bubble per passenger photo', (tester) async {
      await tester.pumpWidget(
        _host(avatars: const ['a.jpg', 'b.jpg'], totalPassengers: 2),
      );

      expect(find.byKey(const ValueKey('passenger-avatar-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('passenger-avatar-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('passenger-avatar-2')), findsNothing);
    });

    testWidgets('counts the passengers whose photo is not shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(avatars: const ['a.jpg', 'b.jpg', 'c.jpg'], totalPassengers: 4),
      );

      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('drops the counter when every passenger has a photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(avatars: const ['a.jpg', 'b.jpg'], totalPassengers: 2),
      );

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('shows the count alone when no passenger has a photo', (
      tester,
    ) async {
      await tester.pumpWidget(_host(avatars: const [], totalPassengers: 3));

      expect(find.text('+3'), findsOneWidget);
      expect(find.byKey(const ValueKey('passenger-avatar-0')), findsNothing);
    });

    testWidgets('renders nothing for a trip nobody booked', (tester) async {
      await tester.pumpWidget(_host(avatars: const [], totalPassengers: 0));

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
