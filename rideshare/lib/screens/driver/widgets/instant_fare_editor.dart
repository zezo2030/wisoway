import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';

/// Turns typed text into a number the way an Arabic keyboard produces it:
/// Arabic-Indic digits and an Arabic comma both have to parse.
double? parseLocalizedFare(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final sb = StringBuffer();
  for (final ch in text.characters) {
    final i = arabic.indexOf(ch);
    if (i >= 0) {
      sb.write(i);
    } else if (ch == '،' || ch == ',') {
      sb.write('.');
    } else {
      sb.write(ch);
    }
  }
  return double.tryParse(sb.toString());
}

/// The step a ± tap moves the fare by. Small fares need fine control; large
/// ones would take dozens of taps at the same granularity.
double fareStepFor(double fare) {
  if (fare >= 100) return 5;
  if (fare >= 20) return 1;
  return 0.25;
}

/// The driver's counter-offer composer: a typed amount flanked by −/+ steppers,
/// bounded by what the server will accept.
///
/// Mirrors the passenger's own fare field so the two sides of the negotiation
/// behave identically — type a number, or nudge it.
class InstantFareEditor extends StatelessWidget {
  final TextEditingController controller;

  /// Lowest acceptable value; the server rejects anything at or below the
  /// passenger's fare, so this is normally `passengerFare + step`.
  final double min;
  final double max;
  final String currency;

  /// Fires after a ± tap or a keystroke, with the parsed value (null while the
  /// field is empty or mid-edit).
  final ValueChanged<double?> onChanged;
  final bool enabled;

  const InstantFareEditor({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.currency,
    required this.onChanged,
    this.enabled = true,
  });

  double get _current => parseLocalizedFare(controller.text) ?? min;

  void _bump(double direction) {
    final step = fareStepFor(_current);
    final next = (_current + direction * step).clamp(min, max);
    final rounded = (next * 100).roundToDouble() / 100;
    controller.text = rounded.toStringAsFixed(2);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    onChanged(rounded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _current;
    final canDecrease = enabled && current - 0.001 > min;
    final canIncrease = enabled && current + 0.001 < max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: T.surfaceVariant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.outlineVariant(context)),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: canDecrease ? () => _bump(-1) : null,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,،]')),
                  ],
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: T.onSurface(context),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    suffixText: currency,
                    suffixStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  onChanged: (value) => onChanged(parseLocalizedFare(value)),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: canIncrease ? () => _bump(1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.instantCounterRangeHint(
            min.toStringAsFixed(2),
            max.toStringAsFixed(2),
            currency,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: T.onSurfaceVariant(context)),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? T.surface(context)
          : T.surface(context).withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? T.primary(context)
                : T.onSurfaceVariant(context).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
