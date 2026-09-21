import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// Small name card drawn over the map next to a pickup / drop-off marker.
///
/// Purely presentational — the owner computes the screen position from
/// `GoogleMapController.getScreenCoordinate()` and hides it when the point
/// scrolls out of the visible map area.
class RouteEndpointLabel extends StatelessWidget {
  final String name;
  final String caption;
  final Color dotColor;

  const RouteEndpointLabel({
    super.key,
    required this.name,
    required this.caption,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$caption: $name',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: T.surface(context),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: T.shadow(context).withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: T.onSurface(context),
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
