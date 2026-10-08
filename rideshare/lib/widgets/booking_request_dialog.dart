import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../core/services/booking_service.dart';
import '../core/services/push_notification_service.dart';
import '../core/theme/colors.dart';
import '../core/ui/error_surface.dart';
import '../l10n/l10n_extensions.dart';
import '../models/booking_request.dart';
import '../screens/driver/widgets/instant_offer_parts.dart';

/// What the driver did with a booking request card.
enum BookingRequestOutcome { accepted, rejected, expired }

/// A choice the driver already made on the pinned notification's buttons.
enum BookingRequestInitialAction {
  accept,
  reject;

  static BookingRequestInitialAction? fromName(String? name) => switch (name) {
    'accept' => accept,
    'reject' => reject,
    _ => null,
  };
}

/// A passenger's request to join one of the driver's shared trips, shown over
/// whatever the driver is doing. It cannot be dismissed: the driver answers it,
/// or it closes itself when the request's acceptance window runs out.
class BookingRequestDialog extends StatefulWidget {
  const BookingRequestDialog({
    super.key,
    required this.request,
    required this.service,
    this.waitingAfterThis = 0,
    this.initialAction,
  });

  final BookingRequest request;
  final BookingService service;

  /// Runs once the card is up: accept straight away, or open the reject
  /// confirmation.
  final BookingRequestInitialAction? initialAction;

  /// Further requests queued behind this one, so the driver knows more follow.
  final int waitingAfterThis;

  @override
  State<BookingRequestDialog> createState() => _BookingRequestDialogState();
}

class _BookingRequestDialogState extends State<BookingRequestDialog> {
  Timer? _ticker;
  late int _secondsLeft;
  late final int _totalSeconds;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.request.expiresAt;
    _secondsLeft = expiresAt == null
        ? 0
        : expiresAt.difference(DateTime.now()).inSeconds;
    final window = expiresAt == null
        ? 0
        : expiresAt.difference(widget.request.createdAt).inSeconds;
    _totalSeconds = window > 0 ? window : _secondsLeft.clamp(1, 1 << 30);
    if (expiresAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _secondsLeft -= 1);
        if (_secondsLeft <= 0) {
          _ticker?.cancel();
          Navigator.of(context).pop(BookingRequestOutcome.expired);
        }
      });
    }
    // Answered on screen now, so the pinned tray entry is redundant.
    PushNotificationService.cancelBookingRequestNotification(widget.request.id);
    final action = widget.initialAction;
    if (action != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (action) {
          case BookingRequestInitialAction.accept:
            _accept();
          case BookingRequestInitialAction.reject:
            _reject();
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    PushNotificationService.cancelBookingRequestNotification(widget.request.id);
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.acceptBooking(widget.request.id);
      if (!mounted) return;
      _ticker?.cancel();
      Navigator.of(context).pop(BookingRequestOutcome.accepted);
    } catch (e) {
      if (!mounted) return;
      // Stay open: a failed accept (e.g. not enough wallet balance) still
      // needs an answer, and declining remains available.
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bookingRequestRejectTitle),
        content: Text(l10n.bookingRequestRejectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.bookingRequestReject),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.rejectBooking(widget.request.id);
      if (!mounted) return;
      _ticker?.cancel();
      Navigator.of(context).pop(BookingRequestOutcome.rejected);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  String _formatLeft(int seconds) {
    final s = seconds.clamp(0, 1 << 30);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.request;
    final locale = Localizations.localeOf(context).toString();
    final amount = r.totalAmount != null
        ? '${r.totalAmount!.toStringAsFixed(2)} ${r.currency}'
        : '—';
    final departure = r.departureTime == null
        ? '—'
        : DateFormat('EEE d MMM · h:mm a', locale).format(r.departureTime!);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: T.surface(context),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 14),
                _passenger(context),
                if (r.seats.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _seatList(context),
                ],
                const SizedBox(height: 14),
                InstantFareHero(
                  earnings: amount,
                  label: l10n.bookingRequestFareLabel,
                ),
                const SizedBox(height: 14),
                InstantRouteBlock(
                  fromName: r.fromName,
                  toName: r.toName,
                  compact: true,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: T.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InstantMetricTile(
                          icon: Icons.event_seat_outlined,
                          label: l10n.bookingRequestSeatsLabel,
                          value: '${r.seatCount}',
                          emphasized: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: InstantMetricTile(
                          icon: Icons.schedule,
                          label: l10n.bookingRequestDepartureLabel,
                          value: departure,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.expiresAt != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    l10n.bookingRequestExpiresIn(_formatLeft(_secondsLeft)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: T.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InstantCountdownBar(
                    secondsLeft: _secondsLeft,
                    totalSeconds: _totalSeconds,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _reject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l10n.bookingRequestReject,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: T.primary(context),
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : Text(
                                  l10n.bookingRequestAccept,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.waitingAfterThis > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.bookingRequestMore(widget.waitingAfterThis),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: T.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: T.primaryContainer(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            l10n.bookingRequestBadge,
            style: TextStyle(
              color: T.onPrimaryContainer(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            l10n.bookingRequestTitle,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: T.onSurface(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  /// Who sits where, companions marked — the whole party before accepting.
  Widget _seatList(BuildContext context) {
    final r = widget.request;
    final booker = r.passengerName ?? context.l10n.passengerFallback;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final seat in r.seats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    Icons.event_seat_outlined,
                    size: 16,
                    color: T.primary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.bookingSeatOccupant(
                        seat.number,
                        seat.name ?? booker,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: T.onSurface(context),
                      ),
                    ),
                  ),
                  if (seat.isCompanion)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: T.primaryContainer(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        context.l10n.bookingCompanionTag,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: T.primary(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _passenger(BuildContext context) {
    final r = widget.request;
    final photo = r.passengerPhotoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final female = r.passengerGender == 'female';
    final accent = female ? T.accentPink(context) : T.primary(context);
    final rating = r.passengerRating ?? 0;

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: accent.withValues(alpha: 0.12),
          backgroundImage: hasPhoto ? CachedNetworkImageProvider(photo) : null,
          child: hasPhoto ? null : Icon(Icons.person, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.passengerName?.trim().isNotEmpty == true
                    ? r.passengerName!
                    : context.l10n.passengerFallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (rating > 0) ...[
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (r.isFamilyBooking)
                    Text(
                      context.l10n.bookingRequestFamily,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: T.primary(context),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
