import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/trip_provider.dart';

import '../../l10n/l10n_extensions.dart';
import '../../screens/driver/trip_management_screen.dart';
import '../../screens/driver/trip_summary_screen.dart';
import '../../screens/passenger/instant_ride_request_screen.dart';
import '../../screens/passenger/ride_payment_due_screen.dart';
import '../../screens/shared/trip_in_progress_screen.dart';
import '../constants/route_names.dart';
import 'instant_ride_service.dart';
import 'notification_navigation_service.dart';

/// Puts the user on their ride's trip screen and keeps them there.
///
/// Once an instant ride is matched, the driver and the passenger both see only
/// the trip screen until it ends. A shared trip holds its driver from the moment
/// it starts and its passengers from departure time: every other route above
/// the root is cleared, and the trip screens block back navigation. Entry points — accepting an offer, a
/// match landing on the passenger, the match and trip pushes, app launch and
/// resume — all come through here so the rule lives in one place.
class ActiveRideNavigator {
  ActiveRideNavigator._();

  static final InstantRideService _service = InstantRideService();

  /// Bumped when a push says someone's boarding changed — the driver said
  /// «معي في السيارة» — so an open trip screen reloads it. [resume] alone
  /// leaves a screen that is already showing untouched.
  static final ValueNotifier<int> presenceChanged = ValueNotifier(0);

  static Timer? _watch;

  /// Asks the server every half minute while the app is open, so a trip whose
  /// time comes takes over the screen without anyone opening its notification.
  static void watch() {
    _watch ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_shownTripId != null) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      resume(rideOnly: true);
    });
  }

  static void stopWatching() {
    _watch?.cancel();
    _watch = null;
  }

  /// The trip whose screen is currently on top, so repeated signals (poll,
  /// push, resume) don't stack it twice.
  static String? _shownTripId;

  static bool isShowing(String tripId) => _shownTripId == tripId;

  /// Opens the driver's locked trip screen.
  static void enterAsDriver(String tripId) => _enter(tripId, isDriver: true);

  /// Opens the passenger's locked trip screen.
  static void enterAsPassenger(String tripId) =>
      _enter(tripId, isDriver: false);

  /// Called by a trip screen when it goes away. [owned] is false for a screen
  /// opened by hand: taking its place must not forget the one shown here.
  static void left(String tripId, {bool owned = true}) {
    if (owned && _shownTripId == tripId) _shownTripId = null;
    _refreshDriverTrips();
  }

  /// The driver home's «رحلاتك الحالية» lists the driver's trips; a ride
  /// starting or ending changes them, so reload rather than wait for a
  /// pull-to-refresh.
  static void _refreshDriverTrips() {
    final context = NotificationNavigationService.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    try {
      unawaited(
        Provider.of<TripProvider>(context, listen: false).fetchDriverTrips(),
      );
    } catch (_) {
      // No provider above the navigator (tests) — nothing to refresh.
    }
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
      // Say plainly what happened — a passing snackbar was easy to miss while
      // the screen swapped under the passenger.
      final context = navigator.context;
      if (context.mounted) {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.info_outline_rounded, size: 32),
              title: Text(ctx.l10n.instantDriverCancelledTitle),
              content: Text(ctx.l10n.instantDriverCancelledBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(ctx.l10n.ok),
                ),
              ],
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Asks the server whether the user is mid-ride and, if so, takes them back.
  /// [rideOnly] leaves a fare still being settled to the next launch or resume.
  static Future<void> resume({bool rideOnly = false}) async {
    try {
      final ride = await _service.getActiveRide();
      if (ride == null) return;
      if (ride.awaitingPayment) {
        if (rideOnly) return;
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
            ? TripManagementScreen(tripId: tripId, lockedUntilEnd: true)
            : TripInProgressScreen(tripId: tripId, lockedUntilEnd: true),
      ),
      (route) => route.isFirst,
    );
    if (isDriver) _refreshDriverTrips();
  }
}
