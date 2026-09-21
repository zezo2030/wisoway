import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import 'default_avatar.dart';

/// Overlapping photos of the passengers already booked on a trip, closed by a
/// "+N" bubble for the ones with no photo to show.
///
/// Only photos reach the client — never names or numbers — so the bubbles stay
/// anonymous by construction.
class PassengerAvatarStack extends StatelessWidget {
  /// Photo URLs, oldest booking first. The backend caps this at three.
  final List<String> avatars;

  /// Everyone on board, photo or not — drives the "+N" bubble.
  final int totalPassengers;

  final double size;

  const PassengerAvatarStack({
    super.key,
    required this.avatars,
    required this.totalPassengers,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPassengers <= 0 && avatars.isEmpty) {
      return const SizedBox.shrink();
    }

    final hidden = totalPassengers - avatars.length;
    final overlap = size * 0.3;

    final bubbles = <Widget>[
      for (var index = 0; index < avatars.length; index++)
        _bubble(
          context,
          key: ValueKey('passenger-avatar-$index'),
          child: CachedNetworkImage(
            imageUrl: avatars[index],
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (_, _) => const DefaultAvatar(),
            errorWidget: (_, _, _) => const DefaultAvatar(),
          ),
        ),
      if (hidden > 0)
        _bubble(
          context,
          key: const ValueKey('passenger-avatar-overflow'),
          background: T.primary(context).withValues(alpha: 0.12),
          child: Center(
            child: Text(
              context.l10n.morePassengersCount(hidden),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.bold,
                color: T.primary(context),
              ),
            ),
          ),
        ),
    ];

    return SizedBox(
      height: size,
      width: bubbles.isEmpty
          ? 0
          : size + (bubbles.length - 1) * (size - overlap),
      child: Stack(
        children: [
          for (var index = 0; index < bubbles.length; index++)
            PositionedDirectional(
              start: index * (size - overlap),
              child: bubbles[index],
            ),
        ],
      ),
    );
  }

  Widget _bubble(
    BuildContext context, {
    required Key key,
    required Widget child,
    Color? background,
  }) {
    return Container(
      key: key,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? T.surface(context),
        border: Border.all(color: T.surface(context), width: 2),
      ),
      child: ClipOval(child: child),
    );
  }
}
