class RouteNames {
  // Auth Routes
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String accountTypeSelection = '/account-type-selection';
  static const String signUp = '/sign-up';
  static const String phoneAuth = '/phone-auth';
  static const String otpVerification = '/otp-verification';
  static const String profileSetup = '/profile-setup';
  static const String driverSignUp = '/driver-sign-up';
  static const String driverCompleteProfile = '/driver-complete-profile';
  static const String driverPendingApproval = '/driver-pending-approval';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Main Routes
  static const String home = '/home';
  static const String main = '/main';

  // Driver Routes
  static const String createTrip = '/create-trip';
  static const String editTrip = '/edit-trip';
  static const String myTrips = '/my-trips';
  static const String tripManagement = '/trip-management';
  static const String passengerDetails = '/passenger-details';
  static const String vehicleSettings = '/vehicle-settings';

  // Passenger Routes
  static const String tripsList = '/trips-list';
  static const String tripDetails = '/trip-details';
  static const String seatSelection = '/seat-selection';
  static const String tripRouteMap = '/trip-route-map';

  // Payment Routes
  static const String manualPayment = '/manual-payment';
  static const String paymentHistory = '/payment-history';
  static const String driverWallet = '/driver-wallet';
  static const String driverWalletTopup = '/driver-wallet-topup';
  static const String passengerWallet = '/passenger-wallet';

  // Notifications
  static const String notifications = '/notifications';

  // Chat Routes
  static const String chat = '/chat';
  static const String driverChat = '/driver-chat';
  static const String groupChat = '/group-chat';

  // Rating Routes
  static const String rating = '/rating';

  // Profile
  static const String editProfile = '/edit-profile';

  // Settings Routes
  static const String settings = '/settings';
  static const String support = '/support';
  static const String about = '/about';
  static const String notificationSettings = '/notification-settings';
  static const String accountSecurity = '/account-security';
  static const String accountSecurityDevices = '/account-security-devices';
  static const String privacySettings = '/privacy-settings';
  static const String inAppBrowser = '/in-app-browser';
  static const String changePassword = '/change-password';

  // Future Routes (for later weeks)
  static const String bookings = '/bookings';
  static const String profile = '/profile';

  // Phase 8 Routes
  static const String banned = '/banned';
  static const String complaint = '/complaint';
  static const String refundRequest = '/refund-request';

  // Pending charges
  static const String pendingCharges = '/pending-charges';
}
