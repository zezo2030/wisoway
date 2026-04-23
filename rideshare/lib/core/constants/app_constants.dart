class AppConstants {
  // App Info
  static const String appName = 'VisionWay';

  // When false, OTP is sent via Twilio. When true, skips sending SMS (dev only).
  static const bool skipOTP = false;

  // No OTP SMS/console codes when OTP is disabled
  static const bool printOTPToConsole = false;

  // Force Firebase Auth - No longer used (removed Anonymous Auth support)
  // static const bool forceFirebaseAuth = false;

  // OTP Configuration (must match backend: 6 digits)
  static const int otpLength = 6;
  static const int otpResendTimeout = 60; // seconds

  // Phone Number Format
  static const String defaultCountryCode = '+20';

  // User Roles
  static const String rolePassenger = 'passenger';
  static const String roleDriver = 'driver';
  static const String roleAdmin = 'admin';

  // User Genders
  static const String genderMale = 'male';
  static const String genderFemale = 'female';

  // Vehicle Types
  static const String vehicleTypeSedan = 'sedan';
  static const String vehicleTypeSUV = 'suv';
  static const String vehicleTypeVan = 'van';
  static const String vehicleTypeTruck = 'truck';
  static const String vehicleTypeMotorcycle = 'motorcycle';
  static const String vehicleTypeBus = 'bus';

  // Vehicle Type Labels (Arabic)
  static const Map<String, String> vehicleTypeLabels = {
    vehicleTypeSedan: 'سيارة سيدان',
    vehicleTypeSUV: 'سيارة دفع رباعي',
    vehicleTypeVan: 'فان',
    vehicleTypeTruck: 'شاحنة',
    vehicleTypeMotorcycle: 'دراجة نارية',
    vehicleTypeBus: 'حافلة',
  };

  // Get all vehicle types
  static List<String> get vehicleTypes => [
    vehicleTypeSedan,
    vehicleTypeSUV,
    vehicleTypeVan,
    vehicleTypeTruck,
    vehicleTypeMotorcycle,
    vehicleTypeBus,
  ];

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String vehiclesCollection = 'vehicles';
  static const String tripsCollection = 'trips';
  static const String bookingsCollection = 'bookings';
  static const String paymentsCollection = 'payments';
  static const String ratingsCollection = 'ratings';
  static const String chatsCollection = 'chats';
  static const String notificationsCollection = 'notifications';

  // SharedPreferences Keys
  static const String keyLanguage = 'language';
  static const String keyTheme = 'theme';

  // Notification Preference Keys
  static const String keyNotifPushEnabled = 'notif_push_enabled';
  static const String keyNotifSound = 'notif_sound';
  static const String keyNotifVibration = 'notif_vibration';
  static const String keyNotifTrips = 'notif_trips';
  static const String keyNotifPayments = 'notif_payments';
  static const String keyNotifMessages = 'notif_messages';
  static const String keyNotifSystem = 'notif_system';

  // Privacy Preference Keys
  static const String keyPrivacyLocationSharing = 'privacy_location_sharing';
  static const String keyPrivacyShowOnline = 'privacy_show_online';
  static const String keyPrivacyShowRating = 'privacy_show_rating';

  // Languages
  static const String langArabic = 'ar';
  static const String langEnglish = 'en';
}
