/// عنوان الباكند:
/// - محاكي أندرويد: 10.0.2.2
/// - محاكي iOS: 127.0.0.1 أو localhost
/// - جهاز حقيقي: IP الكمبيوتر على الشبكة (مثل 192.168.1.5)
/// للتخصيص: flutter run --dart-define=BASE_URL=http://IP:3003/api/v1S
class ApiEndpoints {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    // defaultValue: 'http://localhost:3003/api/v1',
    defaultValue: 'http://192.168.1.4:3003/api/v1',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String linkPhone = '/auth/link-phone';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String me = '/users/me';
  static const String meRole = '/users/me/role';
  static const String meFcmToken = '/users/me/fcm-token';
  static String userById(String id) => '/users/$id';
  static String userStats(String id) => '/users/$id/stats';

  // Trips
  static const String trips = '/trips';
  static const String myTrips = '/trips/my';
  static const String nearbyTrips = '/trips/nearby';
  static const String preferredTrips = '/trips/preferred';
  static String tripById(String id) => '/trips/$id';
  static String tripPricingPreview(String id) => '/trips/$id/pricing-preview';
  static String tripSeats(String id) => '/trips/$id/seats';
  static String tripSeatLock(String id) => '/trips/$id/seats/lock';
  static String hideTrip(String id) => '/trips/$id/hide';
  static String showTrip(String id) => '/trips/$id/show';
  static String completeTrip(String id) => '/trips/$id/complete';
  static String cancelTrip(String id) => '/trips/$id';

  // Bookings
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my';
  static String bookingById(String id) => '/bookings/$id';
  static String tripBookings(String tripId) => '/bookings/trip/$tripId';
  static String confirmBooking(String id) => '/bookings/$id/confirm';
  static String cancelBooking(String id) => '/bookings/$id/cancel';

  // Payments
  static const String payments = '/payments';
  static const String myPayments = '/payments/my';
  static const String communicationFee = '/payments/communication-fee';
  static const String cliqInitiate = '/payments/cliq/initiate';
  static String cliqStatus(String id) => '/payments/$id/cliq-status';
  static String paymentById(String id) => '/payments/$id';
  static String approvePayment(String id) => '/payments/$id/approve';
  static String rejectPayment(String id) => '/payments/$id/reject';
  static const String stripeIntent = '/payments/stripe/create-intent';
  static const String stripePassengerIntent = '/payments/stripe/passenger-intent';

  // Driver wallet
  static const String walletMe = '/payments/wallet/me';
  static const String walletTransactions = '/payments/wallet/transactions';
  static const String walletTopup = '/payments/wallet/topup';
  static const String walletV2Me = '/wallet/me';
  static const String walletV2Transactions = '/wallet/transactions';
  static const String walletV2Topup = '/wallet/topup';
  static const String walletDriverTripCharge = '/wallet/driver/trip-charge';
  static const String walletDriverPayoutRequests =
      '/wallet/driver/payout-requests';
  static const String walletRiderPayTrip = '/wallet/rider/pay-trip';

  // Chat
  static const String chatRooms = '/chat/rooms';
  static String chatRoomByTrip(String tripId) => '/chat/rooms/$tripId';
  static String chatRoomByTripAndPassenger(String tripId, String passengerId) =>
      '/chat/rooms/trip/$tripId/passenger/$passengerId';
  static String chatMessages(String roomId) => '/chat/rooms/$roomId/messages';
  static String sendMessage(String roomId) => '/chat/rooms/$roomId/messages';

  // Ratings
  static const String ratings = '/ratings';
  static const String myRatings = '/ratings/my';
  static String userRatings(String userId) => '/ratings/user/$userId';
  static String tripRatings(String tripId) => '/ratings/trip/$tripId';

  // Vehicles
  static const String vehicles = '/vehicles';
  static const String myVehicle = '/vehicles/my';
  static String vehicleById(String id) => '/vehicles/$id';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadCount = '/notifications/unread-count';
  static const String readAll = '/notifications/read-all';
  static String readNotification(String id) => '/notifications/$id/read';

  // Tracking
  static String trackingLatest(String tripId) => '/tracking/$tripId/latest';
  static String trackingHistory(String tripId) => '/tracking/$tripId/history';
  static const String trackingNearbyTrips = '/tracking/nearby/trips';

  // Uploads
  static const String uploads = '/uploads';
}
