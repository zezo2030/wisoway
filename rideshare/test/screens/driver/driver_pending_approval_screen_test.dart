import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/screens/driver/driver_pending_approval_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves a fixed account and swallows the profile refresh, so the screen's
/// rendering can be pinned to one review outcome.
class _StubAuthProvider extends AuthProvider {
  _StubAuthProvider(this._user);

  final UserModel _user;
  int refreshes = 0;

  @override
  UserModel? get userModel => _user;

  @override
  Future<void> loadUserProfile({bool silent = false}) async {
    refreshes++;
  }
}

UserModel _driver({required bool approved}) => UserModel(
  id: 'd1',
  phoneNumber: '0790000000',
  email: 'd@example.com',
  name: 'محمد',
  gender: 'male',
  role: 'driver',
  isDriverApproved: approved,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  group('DriverPendingApprovalScreen', () {
    testWidgets('shows the review state while the account is pending', (
      tester,
    ) async {
      final auth = await _pump(tester, approved: false);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DriverPendingApprovalScreen)),
      );

      expect(find.text(l10n.driverPendingReviewTitle), findsOneWidget);
      expect(find.text(l10n.driverPendingBadge), findsOneWidget);
      expect(find.text(l10n.driverPendingRestrictionTitle), findsOneWidget);
      expect(find.text(l10n.driverApprovedBadge), findsNothing);
      // Fixing the submission is offered only while it is still pending.
      expect(find.text(l10n.driverEditRegistrationTitle), findsOneWidget);
      expect(auth.refreshes, greaterThan(0));
    });

    // The screen used to render the pending copy unconditionally, so a driver
    // arriving from the "you are approved" notification still read
    // "under review".
    testWidgets('shows the approved state once the account is approved', (
      tester,
    ) async {
      await _pump(tester, approved: true);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DriverPendingApprovalScreen)),
      );

      expect(find.text(l10n.driverApprovedReviewTitle), findsOneWidget);
      expect(find.text(l10n.driverApprovedBadge), findsOneWidget);
      expect(find.text(l10n.driverApprovedRestrictionTitle), findsOneWidget);
      expect(find.text(l10n.driverPendingReviewTitle), findsNothing);
      expect(find.text(l10n.driverPendingBadge), findsNothing);
      expect(find.text(l10n.driverPendingRestrictionTitle), findsNothing);
      expect(find.text(l10n.driverEditRegistrationTitle), findsNothing);
    });

    testWidgets('re-reads the account when the screen opens', (tester) async {
      final auth = await _pump(tester, approved: false);

      // The review outcome only reaches the app through the account, so the
      // screen must not trust the cached profile it was pushed with.
      expect(auth.refreshes, greaterThan(0));
    });
  });
}

Future<_StubAuthProvider> _pump(
  WidgetTester tester, {
  required bool approved,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final auth = _StubAuthProvider(_driver(approved: approved));

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // google_fonts cannot fetch Tajawal in a test and the fallback font is
        // far wider per glyph, so the text is scaled down to keep the layout
        // representative.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.5,
          maxScaleFactor: 0.5,
          child: child!,
        ),
        home: const DriverPendingApprovalScreen(),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return auth;
}
