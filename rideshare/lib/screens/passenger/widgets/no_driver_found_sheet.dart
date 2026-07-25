import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';

/// Terminal state of an instant-ride search: the map stays visible behind this
/// sheet, and the passenger can start a fresh search on the same route, close
/// the flow, or reach support.
class NoDriverFoundSheet extends StatelessWidget {
  /// Starts a new search with the same trip. Disabled while [retrying].
  final Future<void> Function() onRetry;

  /// Closes the finished request; it is already terminal, so nothing is
  /// cancelled server-side.
  final VoidCallback onClose;

  final VoidCallback onSupport;
  final bool retrying;

  const NoDriverFoundSheet({
    super.key,
    required this.onRetry,
    required this.onClose,
    required this.onSupport,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l10n.instantNoDriversIllustrationLabel,
          image: true,
          child: Image.asset(
            'assets/illustrations/no_driver_found.png',
            width: 148,
            height: 148,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.instantNoDrivers,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.instantNoDriversSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: T.onSurfaceVariant(context),
          ),
        ),
        const SizedBox(height: 18),
        _tipCard(context),
        const SizedBox(height: 18),
        _retryButton(context),
        const SizedBox(height: 10),
        _closeButton(context),
        const SizedBox(height: 18),
        _supportRow(context),
      ],
    );
  }

  Widget _tipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: T.primary(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.instantNoDriversTip,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryButton(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        // Null while retrying so a double-tap can't fire a second request.
        onPressed: retrying ? null : () => onRetry(),
        style: ElevatedButton.styleFrom(
          backgroundColor: T.primary(context),
          disabledBackgroundColor: T.primary(context).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: retrying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : const Icon(Icons.refresh, color: AppColors.white),
        label: Text(
          context.l10n.instantTryAgain,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: retrying ? null : onClose,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: T.outlineVariant(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          context.l10n.instantCancelRequest,
          style: TextStyle(
            color: T.onSurface(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _supportRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.headset_mic_outlined,
          size: 18,
          color: T.onSurfaceVariant(context),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.l10n.instantNeedHelp,
            style: TextStyle(
              fontSize: 13,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onSupport,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            context.l10n.instantContactSupport,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: T.primary(context),
            ),
          ),
        ),
      ],
    );
  }
}
