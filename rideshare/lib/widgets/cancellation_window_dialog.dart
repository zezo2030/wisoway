import 'package:flutter/material.dart';

/// Shows a cancellation-window warning before the user confirms a cancellation.
///
/// **When to show:**
/// - Show when the booking is CONFIRMED and departure is within 12 hours, OR
/// - Show reactively after the API returns a 403 with [windowSeconds] in the
///   response body (use [CancellationWindowDialog.fromApiError]).
///
/// Returns `true` if the user confirmed they want to proceed with cancellation
/// despite the penalty, `false` / `null` otherwise.
///
/// Usage (pre-check variant):
/// ```dart
/// final proceed = await CancellationWindowDialog.show(
///   context,
///   departureTime: trip.departureTime,
///   penaltyPercent: 5,
/// );
/// if (proceed == true) bloc.add(BookingCancel(bookingId));
/// ```
///
/// Usage (post-403 variant):
/// ```dart
/// // inside BlocListener when state is BookingError with isCancellationWindowError
/// final proceed = await CancellationWindowDialog.fromApiError(
///   context,
///   windowSeconds: state.windowSeconds,
/// );
/// if (proceed == true) bloc.add(BookingCancel(bookingId));
/// ```
///
/// Phase 4 / T083 — 008-platform-completion.
class CancellationWindowDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;

  const CancellationWindowDialog._({
    required this.title,
    required this.body,
    this.confirmLabel = 'نعم، إلغاء الحجز',
  });

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Pre-check: user is about to cancel, warn them of the potential fee.
  static Future<bool?> show(
    BuildContext context, {
    required DateTime departureTime,
    int penaltyPercent = 5,
  }) {
    final hoursUntil =
        departureTime.difference(DateTime.now()).inHours.abs();
    final body = hoursUntil < 12
        ? 'موعد الرحلة بعد أقل من 12 ساعة. سيُخصم $penaltyPercent٪ من قيمة الحجز '
              'كغرامة إلغاء متأخر. هل تريد الاستمرار؟'
        : 'هل أنت متأكد من إلغاء هذا الحجز؟';

    return showDialog<bool>(
      context: context,
      builder: (_) => CancellationWindowDialog._(
        title: 'تأكيد الإلغاء',
        body: body,
      ),
    );
  }

  /// Post-403: server told us the cancellation window has penalties.
  static Future<bool?> fromApiError(
    BuildContext context, {
    int? windowSeconds,
    int penaltyPercent = 5,
  }) {
    final windowInfo = windowSeconds != null
        ? ' (النافذة المتبقية: ${_formatWindow(windowSeconds)})'
        : '';
    return showDialog<bool>(
      context: context,
      builder: (_) => CancellationWindowDialog._(
        title: 'غرامة إلغاء',
        body: 'لا يمكن الإلغاء مجاناً في هذا الوقت$windowInfo. '
            'سيُخصم $penaltyPercent٪ من قيمة الحجز. هل تريد الاستمرار؟',
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _formatWindow(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      return '$h ساعة';
    }
    final m = seconds ~/ 60;
    return '$m دقيقة';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: colorScheme.error,
        size: 36,
      ),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('لا، تراجع'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
