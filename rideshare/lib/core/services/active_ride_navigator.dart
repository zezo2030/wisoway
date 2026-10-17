import 'package:flutter/material.dart';

import '../../l10n/l10n_extensions.dart';
import '../../screens/driver/trip_management_screen.dart';
import '../../screens/driver/trip_summary_screen.dart';
import '../../screens/passenger/instant_ride_request_screen.dart';
import '../../screens/passenger/ride_payment_due_screen.dart';
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

  /// Key under which a ride's payment screen is tracked, distinct from its
  /// live screen so moving from one to the other isn't mistaken for a repeat.
  static String paymentKey(String tripId) => 'payment:$tripId';

  /// The ride is over but the fare not settled: the passenger waits on the
  /// amount-due screen, the driver confirms on the trip summary.
  static void enterPayment(String tripId, {required bool isDriver}) {
    final key = paymentKey(tripId);
    if (tripId.isEmpty || _shownTripId == key) return;
    final navigator = NotificationNavigationService.navigatorKey.currentState;
    if (navigator == null) return;
    _shownTripId = key;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: RouteSettings(
          name: isDriver ? RouteNames.tripSummary : RouteNames.ridePaymentDue,
          arguments: {'tripId': tripId},
        ),
        builder: (_) => isDriver
            ? TripSummaryScreen(tripId: tripId)
            : RidePaymentDueScreen(tripId: tripId),
      ),
      (route) => route.isFirst,
    );
  }

  /// Re-opens [tripId]'s payment screen when its fare is still open. False
  /// when there's nothing left to settle on that trip.
  static Future<bool> resumePaymentFor(String tripId) async {
    try {
      final ride = await _service.getActiveRide();
      if (ride == null || ride.tripId != tripId || !ride.awaitingPayment) {
        return false;
      }
      enterPayment(tripId, isDriver: ride.isDriver);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The passenger's driver cancelled before pickup and the server is already
  /// searching again: leave the dead trip for the new search. False when no
  /// search is running (nothing to follow).
  static Future<bool> followNewSearch() async {
    try {
      final request = await _service.getSearchingRequest();
      if (request == null) return false;
      final navigator = NotificationNavigationService.navigatorKey.currentState;
      if (navigator == null) return false;
      _shownTripId = null;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => InstantRideRequestScreen(initialRequest: request),
        ),
        (route) => route.isFirst,
      );
      final context = navigator.context;
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.instantDriverCancelledSearching)),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Asks the server whether the user is mid-ride and, if so, takes them back.
  static Future<void> resume() async {
    try {
      final ride = await _service.getActiveRide();
      if (ride == null) return;
      if (ride.awaitingPayment) {
        enterPayment(ride.tripId, isDriver: ride.isDriver);
      } else {
        _enter(ride.tripId, isDriver: ride.isDriver);
      }
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
