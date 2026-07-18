/// عنوان الباكند:
/// - Docker (nginx): http://<IP>/api/v1  (منفذ 80)
/// - تطوير محلي (nest start:dev): http://<IP>:3000/api/v1
/// - محاكي أندرويد + Docker: http://10.0.2.2/api/v1
/// - محاكي أندرويد + nest محلي: http://10.0.2.2:3000/api/v1
/// للتخصيص: flutter run --dart-define=BASE_URL=http://IP/api/v1
class ApiEndpoints {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://vision-way.tech/api/v1',
    // defaultValue: 'http://192.168.1.2/api/v1',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  // Deferred driver registration: verify phone first (no account), then create
  // the account + vehicle atomically in the final step.
  static const String driverVerifyPhone = '/auth/driver/verify-phone';
  static const String driverRegister = '/auth/driver/register';
  static const String linkPhone = '/auth/link-phone';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Password Reset
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyResetOtp = '/auth/verify-reset-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';

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
  static String arriveTrip(String id) => '/trips/$id/arrived';
  static String shareLink(String tripId) => '/trips/$tripId/share-link';
  static String publicShare(String token) => '/share/$token';
  static String passengerConfirm(String bookingId) =>
      '/bookings/$bookingId/passenger-confirm';
  static String driverConfirm(String bookingId) =>
      '/bookings/$bookingId/driver-confirm';
  static String cancelTrip(String id) => '/trips/$id';

  // Bookings (v1 — legacy)
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/my';
  static String bookingById(String id) => '/bookings/$id';
  static String tripBookings(String tripId) => '/bookings/trip/$tripId';
  static String confirmBooking(String id) => '/bookings/$id/confirm';
  static String cancelBooking(String id) => '/bookings/$id/cancel';

  // Bookings (v2 — multi-seat)
  static const String bookingsV2 = '/v2/bookings';
  static const String bookingsV2AutoPick = '/v2/bookings/auto-pick';
  static String acceptBooking(String id) => '/v2/bookings/$id/accept';
  static String rejectBooking(String id) => '/v2/bookings/$id/reject';

  // Pending charges
  static const String myPendingCharges = '/me/pending-charges';
  static const String myPendingChargesCollect = '/me/pending-charges/collect';

  // Payments
  static const String payments = '/payments';
  static const String myPayments = '/payments/my';
  static const String communicationFee = '/payments/communication-fee';
  static const String cliqInitiate = '/payments/cliq/initiate';
  static String cliqStatus(String id) => '/payments/$id/cliq-status';
  static String paymentById(String id) => '/payments/$id';
  static String approvePayment(String id) => '/payments/$id/approve';
  static String rejectPayment(String id) => '/payments/$id/reject';
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
  static String chatRoomById(String roomId) => '/chat/rooms/$roomId';
  static String chatRoomByTrip(String tripId) => '/chat/rooms/$tripId';
  static String chatRoomByTripAndPassenger(String tripId, String passengerId) =>
      '/chat/rooms/trip/$tripId/passenger/$passengerId';
  static String chatRoomByTripGroup(String tripId) =>
      '/chat/rooms/trip/$tripId/group';
  static String chatMessages(String roomId) => '/chat/rooms/$roomId/messages';
  static String sendMessage(String roomId) => '/chat/rooms/$roomId/messages';

  // Ratings
  static const String ratings = '/ratings';
  static const String myRatings = '/ratings/my';
  static String userRatings(String userId) => '/ratings/user/$userId';
  static String tripRatings(String tripId) => '/ratings/trip/$tripId';

  // Vehicles
  static const String vehicles = '/vehicles';
  static const String vehicleTypes = '/vehicles/types';
  static const String myVehicle = '/vehicles/my';
  static String vehicleById(String id) => '/vehicles/$id';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadCount = '/notifications/unread-count';
  static const String readAll = '/notifications/read-all';
  static String readNotification(String id) => '/notifications/$id/read';
  static const String notificationDevices = '/notifications/devices';
  static String notificationDevice(String token) =>
      '/notifications/devices/${Uri.encodeComponent(token)}';

  // Tracking
  static String trackingLatest(String tripId) => '/tracking/$tripId/latest';
  static String trackingHistory(String tripId) => '/tracking/$tripId/history';
  static const String trackingNearbyTrips = '/tracking/nearby/trips';

  // Locations
  static const String locationsRoute = '/locations/route';
  static const String locationsAutocomplete = '/locations/autocomplete';
  static String locationsPlace(String placeId) =>
      '/locations/place/${Uri.encodeComponent(placeId)}';

  // Instant (on-demand) rides
  static const String instantAvailability = '/instant-rides/availability';
  static const String instantHeartbeat =
      '/instant-rides/availability/heartbeat';
  static const String instantAvailabilityMe = '/instant-rides/availability/me';
  static const String instantQuotes = '/instant-rides/quotes';
  static const String instantRequests = '/instant-rides/requests';
  static String instantRequestById(String id) => '/instant-rides/requests/$id';
  static const String instantPendingOffer = '/instant-rides/offers/pending';
  static String instantOfferAccept(String id) =>
      '/instant-rides/offers/$id/accept';
  static String instantOfferDecline(String id) =>
      '/instant-rides/offers/$id/decline';
  static String instantOfferRespond(String id) =>
      '/instant-rides/offers/$id/respond';
  static String instantCounterAccept(String requestId, String offerId) =>
      '/instant-rides/requests/$requestId/offers/$offerId/accept';
  static String instantCounterDecline(String requestId, String offerId) =>
      '/instant-rides/requests/$requestId/offers/$offerId/decline';

  // Uploads
  static const String uploads = '/uploads';
  // Pre-account image upload during driver registration (authorized by the
  // short-lived registration token instead of a session access token).
  static const String uploadsRegistration = '/uploads/registration';

  // Devices (Phase 3 — account security)
  static const String devices = '/auth/devices';
  static String deviceById(String deviceId) => '/auth/devices/$deviceId';
}
