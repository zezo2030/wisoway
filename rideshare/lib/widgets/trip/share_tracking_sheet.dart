import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/share_link_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// Bottom sheet prompting the user to share a live trip-tracking link with
/// someone (e.g. family) when their trip starts. Generates a public share link
/// on demand and hands it to the OS share sheet via `share_plus`.
class ShareTrackingSheet {
  ShareTrackingSheet._();

  static Future<void> show(BuildContext context, String tripId) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShareTrackingSheetContent(tripId: tripId),
    );
  }
}

class _ShareTrackingSheetContent extends StatefulWidget {
  final String tripId;

  const _ShareTrackingSheetContent({required this.tripId});

  @override
  State<_ShareTrackingSheetContent> createState() =>
      _ShareTrackingSheetContentState();
}

class _ShareTrackingSheetContentState
    extends State<_ShareTrackingSheetContent> {
  final ShareLinkService _service = ShareLinkService();
  bool _loading = false;

  Future<void> _share() async {
    setState(() => _loading = true);
    try {
      final url = await _service.createTrackingShareUrl(widget.tripId);
      if (!mounted) return;
      final message = context.l10n.shareTripTrackingText(url);
      Navigator.pop(context);
      await Share.share(message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.shareTripTrackingError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.share_location_outlined,
              size: 48,
              color: T.primary(context),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.shareTripTrackingTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.shareTripTrackingMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: Text(context.l10n.shareTripTrackingLater),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _share,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: Text(context.l10n.shareTripTrackingAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
