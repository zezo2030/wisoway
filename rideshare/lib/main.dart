import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/localization_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/notification_navigation_service.dart';
import 'core/services/push_notification_service.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/trip/trip_bloc.dart';
import 'bloc/booking/booking_bloc.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/notification_provider.dart';
import 'core/constants/route_names.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/account_type_selection_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/phone_auth_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/driver_sign_up_screen.dart';
import 'screens/auth/driver_complete_profile_screen.dart';
import 'screens/driver/driver_pending_approval_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/driver/create_trip_screen.dart';
import 'screens/driver/edit_trip_screen.dart';
import 'screens/driver/my_trips_screen.dart';
import 'screens/driver/vehicle_settings_screen.dart';
import 'screens/driver/trip_management_screen.dart';
import 'screens/driver/passenger_details_screen.dart';
import 'screens/driver/driver_wallet_screen.dart';
import 'screens/driver/pending_charges_screen.dart';
import 'screens/wallet/wallet_topup_request_screen.dart';
import 'screens/passenger/trips_list_screen.dart';
import 'screens/passenger/trip_details_screen.dart';
import 'screens/passenger/seat_selection_screen.dart';
import 'screens/passenger/trip_route_map_screen.dart';
import 'screens/passenger/passenger_wallet_screen.dart';
import 'models/trip_model.dart';
import 'models/booking_model.dart';
import 'screens/payment/manual_payment_screen.dart';
import 'screens/payment/payment_history_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/passenger/chat_screen.dart';
import 'screens/driver/chat_screen.dart' as driver_chat;
import 'screens/passenger/rating_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/change_password_screen.dart';
import 'screens/settings/account_security_devices_screen.dart';
import 'screens/settings/support_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/auth/banned_screen.dart';
import 'screens/passenger/complaint_screen.dart';
import 'screens/passenger/refund_request_screen.dart';
// Removed unused notification_service.dart

//admin@rideshare.com
//Admin@123456

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check to prevent warnings
  // Using debug provider for development, use deviceCheckProvider for production
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        AndroidProvider.debug, // Change to deviceCheckProvider for production
    appleProvider:
        AppleProvider.debug, // Change to deviceCheckProvider for production
  );

  await PushNotificationService.initialize();

  // Note: FirebaseAuth has been replaced with Custom backend REST API.
  // Language settings can be passed in request headers via Interceptors.

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc()),
          BlocProvider(create: (_) => TripBloc()),
          BlocProvider(create: (_) => BookingBloc()),
        ],
        child: Builder(
          builder: (context) {
            return Consumer<LocalizationService>(
              builder: (context, localizationService, child) {
                final themeService = context.watch<ThemeService>();
                return MaterialApp(
                  navigatorKey: NotificationNavigationService.navigatorKey,
                  title: 'VisionWay',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeService.themeMode,
                  locale: localizationService.locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  home: const AuthWrapper(),
                  routes: {
                    RouteNames.welcome: (context) => const WelcomeScreen(),
                    RouteNames.signIn: (context) => const SignInScreen(),
                    RouteNames.accountTypeSelection: (context) =>
                        const AccountTypeSelectionScreen(),
                    RouteNames.signUp: (context) => const SignUpScreen(),
                    RouteNames.driverSignUp: (context) =>
                        const DriverSignUpScreen(),
                    RouteNames.driverCompleteProfile: (context) =>
                        const DriverCompleteProfileScreen(),
                    RouteNames.driverPendingApproval: (context) =>
                        const DriverPendingApprovalScreen(),
                    RouteNames.forgotPassword: (context) =>
                        const ForgotPasswordScreen(),
                    RouteNames.resetPassword: (context) =>
                        const ResetPasswordScreen(),
                    RouteNames.home: (context) => const HomeScreen(),
                    RouteNames.profile: (context) => const HomeScreen(),
                    RouteNames.main: (context) => const MainScreen(),
                    RouteNames.profileSetup: (context) =>
                        const ProfileSetupScreen(),
                    RouteNames.createTrip: (context) =>
                        const CreateTripScreen(),
                    RouteNames.myTrips: (context) => const MyTripsScreen(),
                    RouteNames.vehicleSettings: (context) =>
                        const VehicleSettingsScreen(),
                    RouteNames.tripsList: (context) => const TripsListScreen(),
                    RouteNames.paymentHistory: (context) =>
                        const PaymentHistoryScreen(),
                    RouteNames.driverWallet: (context) =>
                        const DriverWalletScreen(),
                    RouteNames.driverWalletTopup: (context) =>
                        const WalletTopupRequestScreen(),
                    RouteNames.passengerWallet: (context) =>
                        const PassengerWalletScreen(),
                    RouteNames.notifications: (context) =>
                        const NotificationsScreen(),
                    RouteNames.editProfile: (context) =>
                        const EditProfileScreen(),
                    RouteNames.settings: (context) => const SettingsScreen(),
                    RouteNames.support: (context) => const SupportScreen(),
                    RouteNames.about: (context) => const AboutScreen(),
                    RouteNames.changePassword: (context) =>
                        const ChangePasswordScreen(),
                    RouteNames.accountSecurityDevices: (context) =>
                        const AccountSecurityDevicesScreen(),
                    RouteNames.banned: (context) => const BannedScreen(),
                    RouteNames.pendingCharges: (context) =>
                        const PendingChargesScreen(),
                  },
                  onGenerateRoute: (settings) {
                    if (settings.name == RouteNames.complaint) {
                      final args = settings.arguments as Map<String, dynamic>?;
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) => ComplaintScreen(
                          againstUserId: args?['againstUserId'] as String?,
                          tripId: args?['tripId'] as String?,
                        ),
                      );
                    }
                    if (settings.name == RouteNames.refundRequest) {
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) => RefundRequestScreen(
                          bookingId: args['bookingId'] as String,
                          tripRef: args['tripRef'] as String?,
                        ),
                      );
                    }
                    if (settings.name == RouteNames.phoneAuth) {
                      final args = settings.arguments as Map<String, dynamic>?;
                      final isLinkPhone = args?['isLinkPhone'] == true;
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) =>
                            PhoneAuthScreen(isLinkPhone: isLinkPhone),
                      );
                    }
                    if (settings.name == RouteNames.otpVerification) {
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) => OTPVerificationScreen(
                          phoneNumber: args['phoneNumber'],
                        ),
                      );
                    }
                    if (settings.name == RouteNames.tripManagement) {
                      final tripId = settings.arguments as String;
                      return MaterialPageRoute(
                        builder: (context) =>
                            TripManagementScreen(tripId: tripId),
                      );
                    }
                    if (settings.name == RouteNames.editTrip) {
                      final tripId = settings.arguments as String;
                      return MaterialPageRoute(
                        builder: (context) => EditTripScreen(tripId: tripId),
                      );
                    }
                    if (settings.name == RouteNames.tripDetails) {
                      final args = settings.arguments;
                      final tripId = args is Map<String, dynamic>
                          ? args['tripId'] as String
                          : args as String;
                      final booking = args is Map<String, dynamic>
                          ? args['booking'] as BookingModel?
                          : null;
                      return MaterialPageRoute(
                        builder: (context) => TripDetailsScreen(
                          tripId: tripId,
                          initialBooking: booking,
                        ),
                      );
                    }
                    if (settings.name == RouteNames.seatSelection) {
                      final tripId = settings.arguments as String;
                      return MaterialPageRoute(
                        builder: (context) =>
                            SeatSelectionScreen(tripId: tripId),
                      );
                    }
                    if (settings.name == RouteNames.tripRouteMap) {
                      final trip = settings.arguments as TripModel;
                      return MaterialPageRoute(
                        builder: (context) => TripRouteMapScreen(trip: trip),
                      );
                    }
                    if (settings.name == RouteNames.manualPayment) {
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (context) => ManualPaymentScreen(
                          paymentId: args['paymentId'],
                          bookingId: args['bookingId'],
                        ),
                      );
                    }
                    if (settings.name == RouteNames.chat) {
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          tripId: args['tripId'],
                          chatRoomId: args['chatRoomId'],
                          trip: args['trip'],
                          driverId: args['driverId'] ?? '',
                          driverName: args['driverName'],
                        ),
                      );
                    }
                    if (settings.name == RouteNames.driverChat) {
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (context) => driver_chat.DriverChatScreen(
                          tripId: args['tripId'],
                          chatRoomId: args['chatRoomId'],
                          trip: args['trip'],
                          passengerId: args['passengerId'],
                          passengerName: args['passengerName'],
                        ),
                      );
                    }
                    if (settings.name == RouteNames.rating) {
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (context) => RatingScreen(
                          tripId: args['tripId'],
                          trip: args['trip'],
                          driverId: args['driverId'],
                          driverName: args['driverName'],
                        ),
                      );
                    }
                    if (settings.name == RouteNames.passengerDetails) {
                      final booking = settings.arguments as BookingModel;
                      return MaterialPageRoute(
                        builder: (context) =>
                            PassengerDetailsScreen(booking: booking),
                      );
                    }
                    return null;
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading only during initial auth bootstrap.
        if (authProvider.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not authenticated - show welcome screen
        if (!authProvider.isAuthenticated) {
          return const WelcomeScreen();
        }

        // Authenticated but phone not verified - require phone confirmation
        if (!(authProvider.userModel?.isPhoneVerified ?? false)) {
          return const PhoneAuthScreen(isLinkPhone: true);
        }

        // Unapproved drivers still enter HomeScreen and use rider features until approved
        return const HomeScreen();
      },
    );
  }
}
