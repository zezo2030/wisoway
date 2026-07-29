import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/instant_ride_models.dart';
import '../../screens/passenger/trip_details_screen.dart';
import '../../widgets/instant_offer_dialog.dart';
import '../api/api_client.dart';
import '../ui/error_surface.dart';
import 'instant_ride_service.dart';
import 'notification_navigation_service.dart';

/// Handles Accept / Decline / Open coming from the Android rich notification.
class InstantOfferActions {
  InstantOfferActions._();

  static const MethodChannel _channel = MethodChannel(
    'com.abdelaziz.visionway/booking_notification',
  );

  static final InstantRideService _service = InstantRideService();
  static bool _dialogOpen = false;
  static String? _openDialogOfferId;

  static bool get isDialogOpen => _dialogOpen;
  static String? get openDialogOfferId => _openDialogOfferId;

  static Future<void> handle(Map<String, dynamic> data) async {
    final action = data['action']?.toString() ?? 'open';
    final offerId = data['offerId']?.toString() ?? '';
    if (offerId.isEmpty) return;

    switch (action) {
      case 'accept':
        await _accept(offerId);
        break;
      case 'decline':
        await _decline(offerId);
        break;
      case 'open':
      default:
        await openOfferDialog(offerId: offerId, seed: data);
        break;
    }
  }

  static Future<void> openOfferDialog({
    required String offerId,
    Map<String, dynamic>? seed,
  }) async {
    if (_dialogOpen && _openDialogOfferId == offerId) return;

    final context = NotificationNavigationService.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    InstantOffer? offer = await _service.getPendingOffer();
    if (offer == null || offer.id != offerId) {
      offer = _offerFromSeed(offerId, seed);
    }
    if (offer == null) return;

    await _cancelNotification(offerId);

    if (_dialogOpen) return;
    _dialogOpen = true;
    _openDialogOfferId = offerId;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InstantOfferDialog(offer: offer!, service: _service),
      );
    } finally {
      _dialogOpen = false;
      _openDialogOfferId = null;
    }
  }

  static Future<void> _accept(String offerId) async {
    await _cancelNotification(offerId);
    final context = NotificationNavigationService.navigatorKey.currentContext;
    try {
      final request = await _service.acceptOffer(offerId);
      final tripId = request.tripId;
      if (context == null) return;
      if (tripId != null && tripId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: tripId)),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      } else if (kDebugMode) {
        print('instant offer accept failed: $e');
      }
    }
  }

  static Future<void> _decline(String offerId) async {
    await _cancelNotification(offerId);
    try {
      await _service.declineOffer(offerId);
    } catch (_) {
      // ignore — offer may already be gone
    }
  }

  static Future<void> _cancelNotification(String offerId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('cancelInstantOfferNotification', {
        'offerId': offerId,
      });
    } catch (_) {
      // ignore
    }
  }

  static InstantOffer? _offerFromSeed(
    String offerId,
    Map<String, dynamic>? seed,
  ) {
    if (seed == null) return null;
    final requestId = seed['requestId']?.toString() ?? '';
    final expiresAt = seed['expiresAt'] != null
        ? DateTime.tryParse(seed['expiresAt'].toString())
        : null;
    return InstantOffer(
      id: offerId,
      requestId: requestId,
      expiresAt: expiresAt,
      request: InstantRequestSummary(
        id: requestId,
        fromName: seed['fromName']?.toString() ?? '—',
        toName: seed['toName']?.toString() ?? '—',
        currency: seed['currency']?.toString() ?? 'JOD',
        seatCount: 1,
        fareEstimate: seed['fareEstimate']?.toString(),
        passengerFare: seed['passengerFare']?.toString(),
        distanceKm: seed['distanceKm']?.toString(),
        durationMinutes: seed['durationMinutes']?.toString(),
        distanceLabel: seed['distanceLabel']?.toString(),
        durationLabel: seed['durationLabel']?.toString(),
        earningsLabel: seed['earningsLabel']?.toString(),
        tripTypeLabel: seed['tripTypeLabel']?.toString(),
      ),
    );
  }
}
