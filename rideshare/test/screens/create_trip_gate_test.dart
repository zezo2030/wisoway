import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/core/constants/app_constants.dart';
import 'package:rideshare/core/services/auth_service.dart';
import 'package:rideshare/core/services/vehicle_service.dart';
import 'package:rideshare/core/theme/app_theme.dart';
import 'package:rideshare/l10n/generated/app_localizations.dart';
import 'package:rideshare/models/user_model.dart';
import 'package:rideshare/models/vehicle_model.dart';
import 'package:rideshare/models/vehicle_type_template.dart';
import 'package:rideshare/providers/auth_provider.dart';
import 'package:rideshare/providers/trip_provider.dart';
import 'package:rideshare/screens/driver/create_trip_screen.dart';

void main() {
  testWidgets(
    'create-trip gate refreshes pending driver to approved without restart and re-blocks revoked',
    (tester) async {
      final pending = _driver(isApproved: false);
      final approved = _driver(isApproved: true);
      final revoked = _driver(isApproved: false);
      final authService = _FakeAuthService(
        initialUser: pending,
        profileResponses: [approved, revoked],
      );
      final authProvider = AuthProvider(authService: authService);

      await tester.pumpWidget(
        _TestApp(
          authProvider: authProvider,
          child: CreateTripScreen(vehicleService: _FakeVehicleService()),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Create New Trip'), findsOneWidget);
      expect(find.text('Your driver account is under review'), findsNothing);
      expect(authProvider.userModel?.canCreateTrips, isTrue);

      await authProvider.loadUserProfile(silent: true);
      await tester.pumpAndSettle();

      expect(find.text('Your driver account is under review'), findsOneWidget);
      expect(find.text('Create New Trip'), findsNothing);
      expect(authProvider.userModel?.canCreateTrips, isFalse);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.authProvider, required this.child});

  final AuthProvider authProvider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<TripProvider>(create: (_) => TripProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }
}

UserModel _driver({required bool isApproved}) {
  final now = DateTime(2026, 6, 14);
  return UserModel(
    id: isApproved ? 'driver-approved' : 'driver-pending',
    phoneNumber: '+962790000000',
    email: 'driver@example.com',
    name: 'Driver',
    gender: AppConstants.genderMale,
    role: AppConstants.roleDriver,
    isPhoneVerified: true,
    isDriverApproved: isApproved,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required this.initialUser,
    required this.profileResponses,
  });

  final UserModel initialUser;
  final List<UserModel> profileResponses;
  int profileCallCount = 0;

  @override
  Future<UserModel?> checkAuthState() async => initialUser;

  @override
  Future<UserModel> getProfile() async {
    final callIndex = profileCallCount++;
    if (callIndex < profileResponses.length) {
      return profileResponses[callIndex];
    }
    return profileResponses.last;
  }
}

class _FakeVehicleService extends VehicleService {
  @override
  Future<VehicleModel?> getMyVehicle() async => null;

  @override
  Future<List<VehicleTypeTemplate>> getVehicleTypes({
    bool allowCachedFallback = true,
  }) async =>
      [];

  @override
  Future<List<VehicleTypeTemplate>> getCachedVehicleTypes() async => [];
}
