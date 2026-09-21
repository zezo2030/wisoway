import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';

/// Header chrome for the create-trip wizard: three numbered steps joined by
/// connectors. Completed steps show a check, the current step is filled with
/// the brand colour and future steps stay muted.
///
/// The mockup runs progress left-to-right in Arabic too, so the row opts out
/// of RTL mirroring while its labels stay in the app locale.
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

  static const double _circleSize = 34;

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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) _buildConnector(context, done: currentStep >= i),
              _buildStep(context, index: i, label: labels[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnector(BuildContext context, {required bool done}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: _circleSize / 2 - 2),
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: done
                ? T.primary(context)
                : T.outlineVariant(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
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

    // Done steps keep their number and gain a check badge, rather than
    // swapping the number out for a tick: the driver can still read which
    // step they are jumping back to.
    final Color circleColor = isCurrent
        ? primary
        : isCompleted
        ? T.surface(context)
        : T.surfaceVariant(context);
    final Color borderColor = isCurrent || isCompleted
        ? primary
        : T.outlineVariant(context).withValues(alpha: 0.5);
    final Color contentColor = isCurrent
        ? T.onPrimary(context)
        : isCompleted
        ? primary
        : T.onSurfaceVariant(context);

    final circle = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: _circleSize,
          height: _circleSize,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: contentColor,
            ),
          ),
        ),
        if (isCompleted)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
                border: Border.all(color: T.surface(context), width: 1.5),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 9,
                color: T.onPrimary(context),
              ),
            ),
          ),
      ],
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

/// Wizard title bar: back on the left, close on the right.
///
/// Pinned to LTR so the mockup arrangement holds in Arabic as well.
class CreateTripAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CreateTripAppBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AppBar(
        backgroundColor: T.surface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: T.onSurface(context)),
          tooltip: context.l10n.backLabel,
          onPressed: onBack,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: T.onSurface(context)),
            tooltip: context.l10n.close,
            onPressed: onClose,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: T.outline(context)),
        ),
      ),
    );
  }
}

/// Wizard footer: back on the left, the forward/publish action on the right
/// and wider — the mockup arrangement, in both writing directions.
class CreateTripFooter extends StatelessWidget {
  const CreateTripFooter({
    super.key,
    required this.showBack,
    required this.backLabel,
    required this.forwardLabel,
    required this.forwardIcon,
    required this.busy,
    required this.onBack,
    required this.onForward,
    this.maxContentWidth = double.infinity,
  });

  final bool showBack;
  final String backLabel;
  final String forwardLabel;
  final IconData forwardIcon;
  final bool busy;

  /// Null disables the matching button.
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final forward = Expanded(
      child: _PrimaryAction(
        label: forwardLabel,
        icon: forwardIcon,
        busy: busy,
        onPressed: onForward,
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        border: Border(top: BorderSide(color: T.outline(context))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: showBack
                    ? [
                        // Sized to its own label rather than to a fixed share
                        // of the row: "back to editing" is much wider than
                        // "publish", and the fixed share clipped it. Capped so
                        // a long translation still leaves the primary action
                        // the wider of the two.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (constraints.maxWidth - 12) * 0.46,
                          ),
                          child: _SecondaryAction(
                            label: backLabel,
                            icon: Icons.chevron_left_rounded,
                            onPressed: onBack,
                          ),
                        ),
                        const SizedBox(width: 12),
                        forward,
                      ]
                    : [forward],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // The shared text styles bake in a dark text colour, which would win over
    // the button's `foregroundColor`, so the label is coloured explicitly.
    final foreground = onPressed == null
        ? T.onPrimary(context).withValues(alpha: 0.8)
        : T.onPrimary(context);

    return SizedBox(
      height: 52,
      child: Semantics(
        button: true,
        label: label,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: T.primary(context),
            foregroundColor: T.onPrimary(context),
            disabledBackgroundColor: T.primary(context).withValues(alpha: 0.35),
            disabledForegroundColor: T.onPrimary(
              context,
            ).withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _ActionLabel(
            label: label,
            icon: icon,
            busy: busy,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Semantics(
        button: true,
        label: label,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: T.primary(context)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _ActionLabel(
            label: label,
            icon: icon,
            busy: false,
            color: T.primary(context),
          ),
        ),
      ),
    );
  }
}

/// Label with the chevron on its trailing side, as drawn in the mockup.
class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.label,
    required this.icon,
    required this.busy,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Scales down instead of ellipsising: a clipped action label reads as a
    // different action, so the whole row shrinks before any of it is cut.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          if (busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: color ?? AppColors.white,
                strokeWidth: 2.5,
              ),
            )
          else
            Icon(icon, size: 20, color: color),
        ],
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
      MediaQuery.of(context).size.width >= 600 ? 22 : 16;

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: T.onSurfaceVariant(context),
          ),
        ),
      ],
    );
  }
}

/// Header row shared by every card on the wizard steps: a brand-tinted icon
/// chip, the section title, an optional secondary line, and an optional
/// trailing control (a switch, a hint word…).
class CreateTripSectionHeader extends StatelessWidget {
  const CreateTripSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleSuffix,
  });

  final IconData icon;
  final String title;

  /// Secondary line under the title (mockup: "choose how many seats…").
  final String? subtitle;

  /// Pushed to the far end of the row (mockup: the recurrence switch).
  final Widget? trailing;

  /// Muted word rendered right after the title (mockup: "(optional)").
  final String? titleSuffix;

  @override
  Widget build(BuildContext context) {
    final primary = T.primary(context);

    // Centred, not top-aligned: a trailing switch beside a two-line header
    // otherwise floats above the title it belongs to.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                    ),
                  ),
                  if (titleSuffix != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      titleSuffix!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
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
