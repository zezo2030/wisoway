import 'package:flutter/material.dart';

import '../../models/instant_ride_models.dart';
import '../../screens/passenger/trip_details_screen.dart';
import '../../widgets/instant_counter_offer_sheet.dart';
import '../api/api_client.dart';
import '../ui/error_surface.dart';
import 'instant_ride_service.dart';
import 'notification_navigation_service.dart';

/// Brings a driver's counter-offer in front of the passenger wherever they are.
///
/// The searching screen already polls and shows the bid inline, but a passenger
/// who switched away — or whose phone was locked when the driver bid — would
/// otherwise never see it and the offer would simply expire. This is the path
/// from the `instant_counter_offer` push to a decision.
class InstantCounterOfferActions {
  InstantCounterOfferActions._();

  static final InstantRideService _service = InstantRideService();
  static bool _sheetOpen = false;
  static String? _openOfferId;
  static String? _inlineRequestId;

  static bool get isSheetOpen => _sheetOpen;
  static String? get openOfferId => _openOfferId;

  /// Called by a screen that shows counter-offers for [requestId] itself, and
  /// again with null when it goes away.
  static void setInlineHandler(String? requestId) {
    _inlineRequestId = requestId;
  }

  /// Entry point for the push payload. Safe to call more than once for the
  /// same offer — a second call while the sheet is up is ignored.
  static Future<void> handle(Map<String, dynamic> data) async {
    final requestId = data['requestId']?.toString() ?? '';
    final offerId = data['offerId']?.toString() ?? '';
    if (requestId.isEmpty || offerId.isEmpty) return;
    await showCounterOffer(requestId: requestId, offerId: offerId, seed: data);
  }

  static Future<void> showCounterOffer({
    required String requestId,
    required String offerId,
    Map<String, dynamic>? seed,
  }) async {
    if (_sheetOpen && _openOfferId == offerId) return;
    if (_inlineRequestId == requestId) return;

    if (NotificationNavigationService.navigatorKey.currentContext == null) {
      return;
    }

    // Prefer the server's own view of the offer: the push may be stale by the
    // time it is opened, and the passenger must not act on a dead bid.
    InstantCounterOffer? offer;
    try {
      final request = await _service.getRequest(requestId);
      final live = request.counterOffer;
      if (live != null && live.id == offerId) offer = live;
    } catch (_) {
      // Fall through to the push payload.
    }
    offer ??= _fromSeed(offerId, seed);
    if (offer == null || offer.secondsLeft() <= 0) return;

    await _present(offer, requestId, offerId);
  }

  static Future<void> _present(
    InstantCounterOffer offer,
    String requestId,
    String offerId,
  ) {
    final context = NotificationNavigationService.navigatorKey.currentContext;
    if (context == null || _sheetOpen) return Future<void>.value();
    _sheetOpen = true;
    _openOfferId = offerId;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InstantCounterOfferSheet(
        offer: offer,
        onAccept: () => _accept(requestId, offerId),
        onDecline: () => _decline(requestId, offerId),
      ),
    ).whenComplete(() {
      _sheetOpen = false;
      _openOfferId = null;
    });
  }

  static Future<void> _accept(String requestId, String offerId) async {
    final context = NotificationNavigationService.navigatorKey.currentContext;
    try {
      final request = await _service.acceptCounterOffer(requestId, offerId);
      final tripId = request.tripId ?? request.match?.tripId;
      if (context == null || !context.mounted) return;
      if (tripId != null && tripId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: tripId)),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
      rethrow;
    }
  }

  static Future<void> _decline(String requestId, String offerId) async {
    final context = NotificationNavigationService.navigatorKey.currentContext;
    try {
      await _service.declineCounterOffer(requestId, offerId);
    } catch (e) {
      if (context != null && context.mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
      rethrow;
    }
  }

  /// Builds the card straight from the notification when the request lookup
  /// failed — losing the bid to a dropped request would be worse than showing
  /// slightly older numbers.
  static InstantCounterOffer? _fromSeed(
    String offerId,
    Map<String, dynamic>? seed,
  ) {
    if (seed == null) return null;
    final proposed = seed['proposedFare']?.toString() ?? '';
    if (proposed.isEmpty) return null;
    return InstantCounterOffer.fromJson({...seed, 'id': offerId});
  }
}
