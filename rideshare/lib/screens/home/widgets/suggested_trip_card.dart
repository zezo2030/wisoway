import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/trip_model.dart';
import 'passenger_avatar_stack.dart';

/// A trip as it appears in the home carousel: the driver's car photo, when it
/// leaves, the route, what is left of it and who is already on board.
class SuggestedTripCard extends StatelessWidget {
  static const double cardWidth = 208;
  static const double _imageHeight = 104;

  final TripModel trip;
  final VoidCallback onTap;

  const SuggestedTripCard({super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      child: Material(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.outlineVariant(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCover(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRoute(context),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.tripSeatsLeft(trip.availableSeats),
                        style: TextStyle(
                          fontSize: 12,
                          color: T.onSurfaceVariant(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      _buildFooter(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    final photo = trip.carImageUrl;

    return SizedBox(
      height: _imageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null && photo.isNotEmpty)
            CachedNetworkImage(
              imageUrl: photo,
              fit: BoxFit.cover,
              placeholder: (_, _) => _coverFallback(context),
              errorWidget: (_, _, _) => _coverFallback(context),
            )
          else
            _coverFallback(context),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: T.surface(context).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _departureLabel(context),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            T.primary(context).withValues(alpha: 0.22),
            T.primary(context).withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          IconsaxPlusBold.car,
          size: 34,
          color: T.primary(context).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildRoute(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: T.onSurface(context),
    );

    return Row(
      children: [
        Flexible(
          child: Text(
            trip.from.name,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.arrow_back,
            size: 14,
            color: T.onSurfaceVariant(context),
          ),
        ),
        Flexible(
          child: Text(
            trip.to.name,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        PassengerAvatarStack(
          avatars: trip.passengerAvatars,
          totalPassengers: trip.bookedSeats,
        ),
        const Spacer(),
        Text(
          '${_formatFare(trip.price)} ${trip.currency}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: T.primary(context),
          ),
        ),
      ],
    );
  }

  /// "Today · 4:30 PM" while the trip is still today, the date otherwise.
  String _departureLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale).format(trip.departureTime);
    final now = DateTime.now();
    final departure = trip.departureTime;
    final isToday =
        departure.year == now.year &&
        departure.month == now.month &&
        departure.day == now.day;

    if (isToday) return '${context.l10n.tripDepartsToday} • $time';
    return '${DateFormat.MMMd(locale).format(departure)} • $time';
  }

  /// Fares are whole numbers in practice; only show decimals when there are any.
  String _formatFare(double price) {
    if (price == price.roundToDouble()) return price.toStringAsFixed(0);
    return price.toStringAsFixed(2);
  }
}
