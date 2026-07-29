import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

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
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderCard(
            icon: IconsaxPlusLinear.woman,
            label: context.l10n.female,
            selected: value == AppConstants.genderFemale,
            onTap: () => onChanged(AppConstants.genderFemale),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderCard(
            icon: IconsaxPlusLinear.man,
            label: context.l10n.male,
            selected: value == AppConstants.genderMale,
            onTap: () => onChanged(AppConstants.genderMale),
          ),
        ),
      ],
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? T.primary(context) : T.outline(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              if (selected)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: T.primary(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: T.onPrimary(context),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? T.primary(context).withValues(alpha: 0.12)
                          : T.surfaceVariant(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: selected
                          ? T.primary(context)
                          : T.onSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? T.primary(context)
                          : T.onSurface(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
