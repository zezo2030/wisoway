import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/trip_model.dart';
import '../../models/vehicle_colors.dart';

/// Who is coming and how to spot them, on the live ride screen: the car's
/// model, plate and real photo beside the driver, with the ways to reach them
/// underneath.
class TripDriverCard extends StatelessWidget {
  const TripDriverCard({
    super.key,
    required this.trip,
    required this.onDetails,
    required this.onChat,
    required this.onCall,
    this.callBusy = false,
  });

  static const _vehicleFallback =
      'assets/images/trip_in_progress/vehicle_fallback.png';
  static const _avatarFallback =
      'assets/images/trip_in_progress/driver_avatar.png';

  final TripModel trip;
  final VoidCallback onDetails;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final bool callBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: _buildVehicleInfo()),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: _buildCarPhoto()),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: _buildDriverInfo(context)),
              const SizedBox(width: 8),
              _buildAvatar(),
            ],
          ),
          const Divider(height: 20, color: AppColors.slate200),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo() {
    final model = trip.vehicleModel?.trim();
    final plate = trip.vehiclePlateNumber?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model == null || model.isEmpty ? '—' : model,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 6),
        // A long plate shrinks rather than clips: it is how the car is spotted.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              plate == null || plate.isEmpty ? '—' : plate,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.slate800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarPhoto() {
    final carUrl = trip.carImageUrl;
    final color = trip.vehicleColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 64,
            width: double.infinity,
            child: carUrl != null && carUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: carUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Image.asset(_vehicleFallback, fit: BoxFit.contain),
                  )
                : Image.asset(_vehicleFallback, fit: BoxFit.contain),
          ),
        ),
        if (color != null) ...[
          const SizedBox(height: 6),
          _VehicleColorLabel(value: color),
        ],
      ],
    );
  }

  Widget _buildDriverInfo(BuildContext context) {
    final name = trip.driverName?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.isEmpty ? '—' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.teal500,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                context.l10n.tripInProgressYourDriverNow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final photo = trip.driverPhotoUrl;
    final rating = trip.driverRating;

    return SizedBox(
      width: 60,
      height: 68,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.slate200),
            ),
            child: CircleAvatar(
              radius: 27,
              backgroundColor: AppColors.slate200,
              backgroundImage: photo != null && photo.isNotEmpty
                  ? CachedNetworkImageProvider(photo)
                  : const AssetImage(_avatarFallback) as ImageProvider,
            ),
          ),
          if (rating != null && rating > 0)
            Positioned(bottom: 0, child: _RatingBadge(rating: rating)),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onDetails,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal700,
              side: const BorderSide(color: AppColors.teal700),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 44),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    context.l10n.tripInProgressDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 44, color: AppColors.slate200),
        const SizedBox(width: 12),
        _ContactAction(
          icon: Icons.chat_rounded,
          label: context.l10n.tripInProgressMessage,
          onTap: onChat,
        ),
        const SizedBox(width: 12),
        _ContactAction(
          icon: Icons.call_rounded,
          label: context.l10n.call,
          onTap: callBusy ? null : onCall,
          busy: callBusy,
        ),
      ],
    );
  }
}

class _VehicleColorLabel extends StatelessWidget {
  const _VehicleColorLabel({required this.value});

  /// A stored colour: a list key, or free text from before the list existed.
  final String value;

  @override
  Widget build(BuildContext context) {
    final swatch = vehicleColorFor(value)?.swatch;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (swatch != null) ...[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: swatch,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.slate400),
            ),
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            vehicleColorLabel(context.l10n, value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.slate100,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.teal700,
                      ),
                    )
                  : Icon(icon, size: 21, color: AppColors.teal700),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.slate600),
        ),
      ],
    );
  }
}
