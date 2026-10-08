import 'package:flutter/material.dart';

import '../../screens/driver/trip_management_screen.dart';
import '../../screens/shared/trip_in_progress_screen.dart';
import '../constants/route_names.dart';
import 'instant_ride_service.dart';
import 'notification_navigation_service.dart';

/// Puts the user on their instant ride's trip screen and keeps them there.
///
/// Once a ride is matched, the driver and the passenger both see only the trip
/// screen until it ends: every other route above the root is cleared, and the
/// trip screens block back navigation. Entry points — accepting an offer, a
/// match landing on the passenger, the match push, app launch and resume — all
/// come through here so the rule lives in one place.
class ActiveRideNavigator {
  ActiveRideNavigator._();

  static final InstantRideService _service = InstantRideService();

  /// The trip whose screen is currently on top, so repeated signals (poll,
  /// push, resume) don't stack it twice.
  static String? _shownTripId;

  static bool isShowing(String tripId) => _shownTripId == tripId;

  /// Opens the driver's locked trip screen.
  static void enterAsDriver(String tripId) => _enter(tripId, isDriver: true);

  /// Opens the passenger's locked trip screen.
  static void enterAsPassenger(String tripId) =>
      _enter(tripId, isDriver: false);

  /// Called by the trip screen when it goes away (trip ended).
  static void left(String tripId) {
    if (_shownTripId == tripId) _shownTripId = null;
  }

  /// Asks the server whether the user is mid-ride and, if so, takes them back.
  static Future<void> resume() async {
    try {
      final ride = await _service.getActiveRide();
      if (ride == null) return;
      _enter(ride.tripId, isDriver: ride.isDriver);
    } catch (_) {
      // Offline or signed out — the next resume will try again.
    }
  }

  static void _enter(String tripId, {required bool isDriver}) {
    if (tripId.isEmpty || _shownTripId == tripId) return;
    final navigator = NotificationNavigationService.navigatorKey.currentState;
    if (navigator == null) return;
    _shownTripId = tripId;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: RouteSettings(
          name: isDriver
              ? RouteNames.tripManagement
              : RouteNames.tripInProgress,
          arguments: tripId,
        ),
        builder: (_) => isDriver
            ? TripManagementScreen(tripId: tripId)
            : TripInProgressScreen(tripId: tripId, lockedUntilEnd: true),
      ),
      (route) => route.isFirst,
    );
  }
}
