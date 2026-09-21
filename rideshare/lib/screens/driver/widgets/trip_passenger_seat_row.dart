import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/booking_model.dart';

/// One booked seat on the driver's pre-departure roster.
///
/// A booking can hold several seats — a passenger booking two seats brings a
/// companion — and the roster is specified per *seat*, not per booking. This
/// carries the plain values one row needs, so the row stays renderable (and
/// testable) without a `BookingModel`.
class PassengerSeatEntry {
  const PassengerSeatEntry({
    required this.bookingId,
    required this.userId,
    required this.displayName,
    required this.seatNumber,
    required this.phoneNumber,
    required this.rating,
    this.photoUrl,
  });

  final String bookingId;
  final String userId;
  final String displayName;
  final String seatNumber;
  final String phoneNumber;
  final double rating;
  final String? photoUrl;
}

/// Expands bookings into one entry per seat.
///
/// This is the "per-seat, not per-booking" rule the design locks in: a booking
/// of two seats yields two entries. Bookings that predate the seats list fall
/// back to their single `seatNumber`.
List<PassengerSeatEntry> passengerSeatEntries(
  List<BookingModel> bookings, {
  required String fallbackName,
}) {
  final entries = <PassengerSeatEntry>[];
  for (final booking in bookings) {
    final user = booking.userPopulated;
    final bookerName = user?.name ?? fallbackName;

    PassengerSeatEntry entry(String seatNumber, String displayName) =>
        PassengerSeatEntry(
          bookingId: booking.id,
          userId: booking.userId,
          displayName: displayName,
          seatNumber: seatNumber,
          phoneNumber: user?.phoneNumber ?? '',
          rating: user?.rating ?? 0,
          photoUrl: user?.photoUrl,
        );

    if (booking.seats.isNotEmpty) {
      for (final seat in booking.seats) {
        entries.add(
          entry(
            seat.seatNumber,
            seat.displayName.trim().isNotEmpty ? seat.displayName : bookerName,
          ),
        );
      }
    } else {
      entries.add(entry(booking.seatNumber ?? '', bookerName));
    }
  }
  return entries;
}

/// A single roster row: avatar, name, rating, seat chip, chat and call.
///
/// Contact is unconditional — the pay-to-unlock gate was removed earlier in
/// this plan, so there is no branch on `hasDriverPaidToContact` here.
class TripPassengerSeatRow extends StatelessWidget {
  const TripPassengerSeatRow({
    super.key,
    required this.displayName,
    required this.seatNumber,
    required this.rating,
    required this.photoUrl,
    required this.onChat,
    required this.onCall,
  });

  final String displayName;
  final String seatNumber;
  final double rating;
  final String? photoUrl;
  final VoidCallback? onChat;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          PassengerAvatar(photoUrl: photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      IconsaxPlusBold.star,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: T.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (seatNumber.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: T.primaryContainer(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.l10n.seatChipLabel(seatNumber),
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onPrimaryContainer(context),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          CircleIconButton(
            icon: Icon(
              IconsaxPlusLinear.message,
              size: 18,
              color: T.primary(context),
            ),
            tooltip: context.l10n.chat,
            bordered: true,
            onPressed: onChat,
          ),
          const SizedBox(width: 8),
          CircleIconButton(
            icon: Icon(
              IconsaxPlusLinear.call,
              size: 18,
              color: T.primary(context),
            ),
            tooltip: context.l10n.call,
            bordered: true,
            onPressed: onCall,
          ),
        ],
      ),
    );
  }
}

/// Circular button used by the pre-departure header and the roster's chat and
/// call actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.bordered = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: T.surface(context),
        shape: BoxShape.circle,
        border: bordered
            ? Border.all(color: T.primary(context).withValues(alpha: 0.3))
            : null,
        boxShadow: bordered
            ? null
            : [
                BoxShadow(
                  color: T.shadow(context).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}

/// Passenger avatar: the profile photo when there is one, otherwise a neutral
/// profile glyph.
class PassengerAvatar extends StatelessWidget {
  const PassengerAvatar({super.key, required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: T.primaryContainer(context),
        shape: BoxShape.circle,
      ),
      child: Icon(IconsaxPlusBold.profile, size: 22, color: T.primary(context)),
    );
  }
}
