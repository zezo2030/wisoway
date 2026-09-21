import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';

/// Shared building blocks for the two surfaces a driver sees an instant-ride
/// request on: the compact card that interrupts them, and the full details
/// screen behind it. Keeping them here is what makes the two read as the same
/// offer rather than two different designs.

/// Pickup → dropoff with a connecting rail, each stop optionally carrying its
/// full street line underneath the short place name.
class InstantRouteBlock extends StatelessWidget {
  final String fromName;
  final String toName;
  final String? fromAddress;
  final String? toAddress;

  /// Compact drops the address lines and tightens the spacing, for the card.
  final bool compact;

  const InstantRouteBlock({
    super.key,
    required this.fromName,
    required this.toName,
    this.fromAddress,
    this.toAddress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Rail(compact: compact),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stop(
                label: l10n.instantFormFromLabel,
                name: fromName,
                address: compact ? null : fromAddress,
              ),
              SizedBox(height: compact ? 14 : 20),
              _Stop(
                label: l10n.instantFormToLabel,
                name: toName,
                address: compact ? null : toAddress,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  final bool compact;

  const _Rail({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: T.primary(context),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 2,
            height: compact ? 30 : 46,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: T.outlineVariant(context),
          ),
          Icon(Icons.location_on, size: 17, color: T.error(context)),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  final String label;
  final String name;
  final String? address;

  const _Stop({required this.label, required this.name, this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: T.onSurfaceVariant(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: T.onSurface(context),
          ),
        ),
        if (address != null && address!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            address!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// One labelled figure in the metrics strip/grid.
class InstantMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Highlights the figure that decides whether the job is worth taking.
  final bool emphasized;

  const InstantMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = emphasized ? T.primary(context) : T.onSurface(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: T.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "ينتهي خلال N ثانية" plus the draining bar underneath it.
class InstantCountdownBar extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const InstantCountdownBar({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    // Under ten seconds the decision is urgent, and the bar says so.
    final urgent = secondsLeft <= 10;
    final color = urgent ? T.error(context) : T.primary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.instantOfferCountdown(secondsLeft < 0 ? 0 : secondsLeft),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: urgent ? color : T.onSurfaceVariant(context),
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: totalSeconds <= 0
                ? 0
                : (secondsLeft / totalSeconds).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: T.surfaceVariant(context),
            color: color,
          ),
        ),
      ],
    );
  }
}

/// The fare the passenger is offering, as the loudest thing on the surface —
/// it is the one number a driver decides on.
class InstantFareHero extends StatelessWidget {
  final String earnings;
  final String label;
  final String? note;

  const InstantFareHero({
    super.key,
    required this.earnings,
    required this.label,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            earnings,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: T.primary(context),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 3),
          Text(
            note!,
            style: TextStyle(
              fontSize: 11.5,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Passenger identity on the offer: who the driver would be picking up.
class InstantPassengerRow extends StatelessWidget {
  final String? name;
  final double? rating;
  final int? totalRatings;
  final String? photoUrl;
  final String seatsLabel;

  const InstantPassengerRow({
    super.key,
    required this.seatsLabel,
    this.name,
    this.rating,
    this.totalRatings,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName = (name == null || name!.isEmpty)
        ? l10n.instantOfferPassengersLabel
        : name!;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: T.surfaceVariant(context),
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Icon(
                  Icons.person_outline,
                  color: T.onSurfaceVariant(context),
                  size: 22,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (rating != null) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      totalRatings != null && totalRatings! > 0
                          ? '${rating!.toStringAsFixed(1)} ($totalRatings)'
                          : rating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                    Icons.person_outline,
                    size: 15,
                    color: T.onSurfaceVariant(context),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    seatsLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: T.onSurfaceVariant(context),
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

/// A plain white/surface card with the padding the offer surfaces share.
class InstantSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const InstantSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      child: child,
    );
  }
}
