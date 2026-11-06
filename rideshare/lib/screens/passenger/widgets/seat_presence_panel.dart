import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/services/presence_service.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/presence_models.dart';

/// Asks whether each passenger on the booking is in the car, one seat at a time.
///
/// A seat shows only the answers still open to it, so a final answer takes its
/// buttons away. [onChanged] receives the prompt as the server now has it.
class SeatPresencePanel extends StatefulWidget {
  const SeatPresencePanel({
    super.key,
    required this.prompt,
    required this.gateway,
    required this.onChanged,
  });

  final PresencePrompt prompt;
  final PresenceGateway gateway;
  final ValueChanged<PresencePrompt> onChanged;

  @override
  State<SeatPresencePanel> createState() => _SeatPresencePanelState();
}

class _SeatPresencePanelState extends State<SeatPresencePanel> {
  String? _submittingSeat;

  Future<void> _answer(
    PresencePromptSeat seat,
    PassengerPresenceStatus status,
  ) async {
    if (status == PassengerPresenceStatus.notRiding &&
        !await _confirmNotRiding(seat)) {
      return;
    }
    if (!mounted) return;
    final failedMessage = context.l10n.presenceSubmitFailed;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submittingSeat = seat.seatNumber);
    try {
      await widget.gateway.declare(widget.prompt.bookingId, status, [
        seat.seatNumber,
      ]);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
    }
    try {
      // Also after a failure: another device may have answered first.
      final prompt = await widget.gateway.getPrompt(widget.prompt.bookingId);
      if (mounted) widget.onChanged(prompt);
    } catch (_) {
      // The buttons stay, so the passenger can try again.
    }
    if (mounted) setState(() => _submittingSeat = null);
  }

  Future<bool> _confirmNotRiding(PresencePromptSeat seat) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.presenceNotRidingConfirmTitle(seat.displayName)),
        content: Text(l10n.presenceNotRidingConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.presenceNotRidingConfirmAction),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.presenceQuestionTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.presenceQuestionSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: T.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        for (final seat in widget.prompt.seats)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SeatRow(
              seat: seat,
              busy: _submittingSeat != null,
              submitting: _submittingSeat == seat.seatNumber,
              onAnswer: (status) => _answer(seat, status),
            ),
          ),
      ],
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.seat,
    required this.busy,
    required this.submitting,
    required this.onAnswer,
  });

  final PresencePromptSeat seat;
  final bool busy;
  final bool submitting;
  final ValueChanged<PassengerPresenceStatus> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = seat.declaredStatus;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusLinear.user, size: 18, color: T.primary(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  seat.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (submitting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (status != null)
                _StatusLabel(status: status),
            ],
          ),
          if (!seat.isSettled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (index, answer) in seat.openAnswers.indexed) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _AnswerButton(
                      label: _answerLabel(context, answer),
                      answer: answer,
                      onPressed: busy ? null : () => onAnswer(answer),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _answerLabel(BuildContext context, PassengerPresenceStatus answer) {
    final l10n = context.l10n;
    return switch (answer) {
      PassengerPresenceStatus.inVehicle =>
        seat.declaredStatus == PassengerPresenceStatus.onMyWay
            ? l10n.presenceSeatArrived
            : l10n.presenceSeatInVehicle,
      PassengerPresenceStatus.onMyWay => l10n.presenceSeatOnMyWay,
      PassengerPresenceStatus.notRiding => l10n.presenceSeatNotRiding,
    };
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.answer,
    required this.onPressed,
  });

  final String label;
  final PassengerPresenceStatus answer;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 10);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
    if (answer == PassengerPresenceStatus.inVehicle) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: T.primary(context),
          foregroundColor: Colors.white,
          padding: padding,
        ),
        child: text,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: answer == PassengerPresenceStatus.notRiding
            ? AppColors.errorDark
            : T.onSurface(context),
        padding: padding,
      ),
      child: text,
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final PassengerPresenceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      PassengerPresenceStatus.inVehicle => (
        l10n.presenceSeatInVehicle,
        T.primary(context),
      ),
      PassengerPresenceStatus.onMyWay => (
        l10n.presenceSeatOnMyWay,
        AppColors.warningDark,
      ),
      PassengerPresenceStatus.notRiding => (
        l10n.presenceSeatNotRiding,
        AppColors.errorDark,
      ),
    };
    return Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    );
  }
}
