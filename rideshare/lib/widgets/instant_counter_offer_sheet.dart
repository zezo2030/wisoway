import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/utils/backend_url_resolver.dart';
import '../l10n/l10n_extensions.dart';
import '../models/instant_ride_models.dart';
import '../screens/driver/widgets/instant_offer_parts.dart';

/// The driver's bid, as the passenger sees it.
///
/// This is the mirror image of the card the driver gets: same countdown, same
/// two-button decision, same prominence for the one number being negotiated.
/// It is a dialog rather than a panel inside one screen because a counter-offer
/// can land while the passenger is anywhere in the app.
class InstantCounterOfferSheet extends StatefulWidget {
  final InstantCounterOffer offer;

  /// Both return once the server has answered, so the sheet can close on the
  /// real outcome rather than optimistically.
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const InstantCounterOfferSheet({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<InstantCounterOfferSheet> createState() =>
      _InstantCounterOfferSheetState();
}

class _InstantCounterOfferSheetState extends State<InstantCounterOfferSheet> {
  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.offer.secondsLeft();
    _secondsLeft = remaining > 0 ? remaining : 30;
    _totalSeconds = _secondsLeft;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      // The server drops the offer at the same deadline, so holding the sheet
      // open past it would only invite a doomed tap.
      if (_secondsLeft <= 0) {
        _ticker?.cancel();
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _ticker?.cancel();
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      // The caller surfaces the failure; keep the sheet so the passenger can
      // retry the other option.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offer = widget.offer;

    return Dialog(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: T.primaryContainer(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.instantCounterBadge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: T.onPrimaryContainer(context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      l10n.instantDriverOfferTitle,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: T.onSurface(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _driverRow(context),
              const SizedBox(height: 16),
              _priceRow(context),
              if (offer.fromName != null && offer.toName != null) ...[
                const SizedBox(height: 16),
                InstantRouteBlock(
                  fromName: offer.fromName!,
                  toName: offer.toName!,
                  compact: true,
                ),
              ],
              const SizedBox(height: 16),
              InstantCountdownBar(
                secondsLeft: _secondsLeft,
                totalSeconds: _totalSeconds,
              ),
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverRow(BuildContext context) {
    final offer = widget.offer;
    final photo = BackendUrlResolver.normalize(offer.driverPhotoUrl);
    final subtitle = [
      if (offer.vehicleModel != null) offer.vehicleModel!,
      if (offer.plateNumber != null) offer.plateNumber!,
    ].join(' · ');

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: T.surfaceVariant(context),
          backgroundImage: photo != null ? NetworkImage(photo) : null,
          child: photo == null
              ? Icon(
                  Icons.person_outline,
                  color: T.onSurfaceVariant(context),
                  size: 24,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.driverName ?? context.l10n.instantDriverOfferTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              if (offer.driverRating != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      offer.driverTotalRatings != null &&
                              offer.driverTotalRatings! > 0
                          ? '${offer.driverRating!.toStringAsFixed(1)} (${offer.driverTotalRatings})'
                          : offer.driverRating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The driver's price, with the passenger's own asking fare struck through
  /// beside it — the difference is the whole decision.
  Widget _priceRow(BuildContext context) {
    final l10n = context.l10n;
    final offer = widget.offer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.instantCounterProposedLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${offer.proposedFare} ${offer.currency}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: T.primary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (offer.passengerFare != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.instantYourFareLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${offer.passengerFare} ${offer.currency}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _busy ? null : () => _run(widget.onDecline),
              style: OutlinedButton.styleFrom(
                foregroundColor: T.onSurface(context),
                side: BorderSide(color: T.outlineVariant(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.instantDecline,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _run(widget.onAccept),
              style: ElevatedButton.styleFrom(
                backgroundColor: T.primary(context),
                foregroundColor: T.onPrimary(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          T.onPrimary(context),
                        ),
                      ),
                    )
                  : Text(
                      l10n.instantAccept,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
