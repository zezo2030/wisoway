import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// Male/female picker used on both signup step 1 screens.
///
/// [value] is one of [AppConstants.genderMale] / [AppConstants.genderFemale],
/// or null when nothing is chosen yet.
class GenderSelectCards extends StatelessWidget {
  const GenderSelectCards({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  /// Section caption drawn above the pair, e.g. "Gender *". Owned here so both
  /// signup screens render the required marker the same way.
  final String? label;

  @override
  Widget build(BuildContext context) {
    // The mockup fixes the pair physically -- female left, male right -- so the
    // row lays out LTR regardless of the reading direction. Only this row's own
    // ordering is pinned; the labels inside keep the ambient directionality.
    final cards = Row(
      textDirection: TextDirection.ltr,
      children: [
        Expanded(
          child: _GenderCard(
            icon: Icons.female,
            label: context.l10n.female,
            selected: value == AppConstants.genderFemale,
            onTap: () => onChanged(AppConstants.genderFemale),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderCard(
            icon: Icons.male,
            label: context.l10n.male,
            selected: value == AppConstants.genderMale,
            onTap: () => onChanged(AppConstants.genderMale),
          ),
        ),
      ],
    );

    final caption = label;
    if (caption == null) return cards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _RequiredLabel(caption),
        ),
        const SizedBox(height: 10),
        cards,
      ],
    );
  }
}

/// Renders a "Label *" caption with the trailing asterisk in the error colour,
/// as the mockup draws it.
class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: T.onSurface(context),
    );
    final asterisk = text.lastIndexOf('*');

    if (asterisk == -1) return Text(text, style: base);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, asterisk)),
          TextSpan(
            text: text.substring(asterisk),
            style: TextStyle(color: T.error(context)),
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = T.primary(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // Same padding, radius and shadow as the fields above it, so the pair
          // reads as one more row of the form rather than two posters.
          padding: const EdgeInsetsDirectional.only(
            start: 10,
            end: 10,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.06)
                : T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primary : T.outline(context),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: T.shadow(context).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? primary : primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? T.onPrimary(context) : primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? primary : T.onSurface(context),
                  ),
                ),
              ),
              // The tick follows the reading direction: on the compact row it
              // closes the card, where the tall mockup card had a free corner.
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 13,
                    color: T.onPrimary(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
