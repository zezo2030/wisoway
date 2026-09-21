import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Numbered 1/2/3 progress chrome shared by every auth wizard screen.
///
/// Steps before [currentStep] are drawn as completed check circles, the current
/// step keeps its number highlighted, and later steps stay muted. Deliberately
/// free of localization lookups so it can be rendered in isolation (tests and
/// previews) without an [AppLocalizations] ancestor.
class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels,
    this.circleSize = 30,
  });

  /// 1-based index of the active step.
  final int currentStep;

  final int totalSteps;

  /// Optional caption under each circle; must have [totalSteps] entries.
  final List<String>? labels;

  final double circleSize;

  @override
  Widget build(BuildContext context) {
    final captions = labels;
    final hasCaptions = captions != null && captions.length == totalSteps;

    final row = <Widget>[];
    for (var step = 1; step <= totalSteps; step++) {
      if (step > 1) {
        row.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: step <= currentStep
                  ? T.primary(context)
                  : T.outlineVariant(context),
            ),
          ),
        );
      }
      row.add(_StepCircle(step: step, current: currentStep, size: circleSize));
    }

    if (!hasCaptions) {
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: row);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: row),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var step = 1; step <= totalSteps; step++)
              Expanded(
                child: Text(
                  captions[step - 1],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: step == currentStep
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: step <= currentStep
                        ? T.primary(context)
                        : T.onSurfaceVariant(context),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.step,
    required this.current,
    required this.size,
  });

  final int step;
  final int current;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDone = step < current;
    final isActive = step == current;
    final filled = isDone || isActive;

    return Semantics(
      label: 'Step $step',
      selected: isActive,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? T.primary(context) : T.surface(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: filled ? T.primary(context) : T.outlineVariant(context),
            width: 1.6,
          ),
        ),
        child: isDone
            ? Icon(Icons.check, size: size * 0.55, color: T.onPrimary(context))
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? T.onPrimary(context)
                      : T.onSurfaceVariant(context),
                ),
              ),
      ),
    );
  }
}
