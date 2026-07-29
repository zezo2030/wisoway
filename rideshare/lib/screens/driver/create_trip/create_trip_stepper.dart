import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';

/// Header chrome for the create-trip wizard: three numbered steps joined by
/// connectors. Completed steps show a check, the current step is filled with
/// the brand colour and future steps stay muted.
///
/// Layout is built from a [Row], so it mirrors automatically in RTL.
class CreateTripStepper extends StatelessWidget {
  const CreateTripStepper({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  /// Active step index (`0` route, `1` details, `2` review).
  final int currentStep;

  /// Called when a *completed* step is tapped; forward steps are not tappable.
  final ValueChanged<int>? onStepTapped;

  static const double _circleSize = 30;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      context.l10n.createTripStepRoute,
      context.l10n.createTripStepDetails,
      context.l10n.createTripStepReview,
    ];

    return Container(
      width: double.infinity,
      color: T.surface(context),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) _buildConnector(context, done: currentStep >= i),
            _buildStep(context, index: i, label: labels[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildConnector(BuildContext context, {required bool done}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: _circleSize / 2 - 1),
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            color: done
                ? T.primary(context)
                : T.outlineVariant(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int index,
    required String label,
  }) {
    final isCompleted = index < currentStep;
    final isCurrent = index == currentStep;
    final primary = T.primary(context);

    final Color circleColor = isCurrent
        ? primary
        : (isCompleted ? T.surface(context) : T.surfaceVariant(context));
    final Color borderColor = isCurrent || isCompleted
        ? primary
        : T.outlineVariant(context).withValues(alpha: 0.5);
    final Color contentColor = isCurrent
        ? T.onPrimary(context)
        : (isCompleted ? primary : T.onSurfaceVariant(context));

    final circle = Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      alignment: Alignment.center,
      child: isCompleted
          ? Icon(Icons.check_rounded, size: 18, color: contentColor)
          : Text(
              '${index + 1}',
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent || isCompleted
                ? primary
                : T.onSurfaceVariant(context),
          ),
        ),
      ],
    );

    return SizedBox(
      width: 88,
      child: Semantics(
        button: isCompleted && onStepTapped != null,
        selected: isCurrent,
        label: label,
        child: isCompleted && onStepTapped != null
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onStepTapped!(index),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Rounded surface card shared by every wizard step (same treatment the
/// pre-wizard create-trip form used for its sections).
class CreateTripCard extends StatelessWidget {
  const CreateTripCard({super.key, required this.child});

  final Widget child;

  static double paddingFor(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 ? 28 : 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(paddingFor(context)),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: T.outline(context)),
        boxShadow: [
          BoxShadow(
            color: T.surface(context).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Title + subtitle block shown at the top of each wizard step.
class CreateTripStepHeader extends StatelessWidget {
  const CreateTripStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: T.onSurfaceVariant(context),
          ),
        ),
      ],
    );
  }
}

/// Tappable read-only field (date, time, recurrence end date…) reused across
/// wizard steps.
class CreateTripPickerField extends StatelessWidget {
  const CreateTripPickerField({
    super.key,
    required this.hint,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String hint;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;
    return Semantics(
      button: true,
      label: hint,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.outline(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEmpty ? hint : value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                    color: isEmpty
                        ? T.textSecondary(context)
                        : T.onSurface(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: T.outlineVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
