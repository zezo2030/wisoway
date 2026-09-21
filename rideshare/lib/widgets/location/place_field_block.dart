import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';

/// One tappable place field on a form: a filled block with a marker, the
/// chosen place, and a chevron.
///
/// This is inDrive's route-form row. Nothing is typed here — tapping opens a
/// picker — which is what keeps every place in the app resolved through one
/// search path. The label appears only once a place is chosen, so an empty
/// block asks for what it wants through its hint instead of stacking both.
class PlaceFieldBlock extends StatelessWidget {
  const PlaceFieldBlock({
    super.key,
    required this.indicator,
    required this.hint,
    required this.onTap,
    this.label,
    this.value,
    this.busy = false,
    this.trailing,
  });

  /// Leading marker — a coloured ring for a route endpoint, an icon for a city.
  final Widget indicator;

  final String hint;
  final String? label;
  final String? value;

  /// Swaps the chevron for a spinner while the value is being filled in.
  final bool busy;

  /// Replaces the chevron entirely, e.g. with a different affordance.
  final Widget? trailing;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Material(
      color: T.surfaceVariant(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          button: true,
          label: label,
          value: hasValue ? value : hint,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
            child: Row(
              children: [
                SizedBox(width: 22, child: Center(child: indicator)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label != null && hasValue) ...[
                        Text(
                          label!,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: T.onSurfaceVariant(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        hasValue ? value! : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 15,
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: hasValue
                              ? T.onSurface(context)
                              : T.onSurfaceVariant(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  trailing ??
                      Icon(
                        // Material's chevrons do not mirror themselves, and
                        // this one points the way the app reads.
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        size: 22,
                        color: T.onSurfaceVariant(context),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The open circle inDrive uses to mark a route endpoint: green for A, red
/// for B.
class RouteEndpointRing extends StatelessWidget {
  const RouteEndpointRing({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3.5),
      ),
    );
  }
}
