import 'package:flutter/material.dart';

import '../../widgets/booking_request_dialog.dart';
import '../theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import 'booking_service.dart';
import 'notification_navigation_service.dart';

/// Puts the driver's waiting booking requests in front of them, one card at a
/// time, until none are left.
///
/// A shared-trip booking request used to arrive as an ordinary notification
/// that was easy to swipe away, leaving the passenger waiting until the
/// request quietly expired. Every signal that a request may be waiting — the
/// push arriving or being tapped, the app opening or coming back — calls
/// [showPending], which asks the server for what is actually outstanding.
class BookingRequestActions {
  BookingRequestActions._();

  static final BookingService _service = BookingService();
  static bool _running = false;

  /// Requests already answered or expired on this device, so a stale server
  /// read can't bring the same card back.
  static final Set<String> _handled = {};

  /// [focusBookingId] puts that request's card up first, and [initialAction]
  /// (from the notification's buttons) starts the driver's choice on it.
  static Future<void> showPending({
    String? focusBookingId,
    BookingRequestInitialAction? initialAction,
  }) async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final context =
            NotificationNavigationService.navigatorKey.currentContext;
        if (context == null || !context.mounted) return;

        final List pending;
        try {
          pending = (await _service.getPendingRequests())
              .where((r) => !_handled.contains(r.id))
              .toList();
        } catch (_) {
          // Not a driver, offline or signed out — nothing to show.
          return;
        }
        if (pending.isEmpty) return;

        final focused = pending.where((r) => r.id == focusBookingId);
        final request = focused.isNotEmpty ? focused.first : pending.first;
        // The button choice applies to its own request, and only once.
        final action = request.id == focusBookingId ? initialAction : null;
        focusBookingId = null;
        if (!context.mounted) return;
        final outcome = await showDialog<BookingRequestOutcome>(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => BookingRequestDialog(
            request: request,
            service: _service,
            waitingAfterThis: pending.length - 1,
            initialAction: action,
          ),
        );
        _handled.add(request.id);

        final after = NotificationNavigationService.navigatorKey.currentContext;
        if (after != null && after.mounted && outcome != null) {
          final l10n = after.l10n;
          ScaffoldMessenger.maybeOf(after)?.showSnackBar(
            SnackBar(
              content: Text(switch (outcome) {
                BookingRequestOutcome.accepted => l10n.bookingRequestAccepted,
                BookingRequestOutcome.rejected => l10n.bookingRejected,
                BookingRequestOutcome.expired => l10n.bookingRequestExpired,
              }),
              backgroundColor: outcome == BookingRequestOutcome.accepted
                  ? AppColors.success
                  : null,
            ),
          );
        }
      }
    } finally {
      _running = false;
    }
  }
}
