import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../l10n/l10n_extensions.dart';
import '../models/vehicle_colors.dart';

/// Picks the vehicle's colour from [kVehicleColors]. Reports the colour's
/// key, which is what is stored on the vehicle.
///
/// A value saved before the list existed is matched by name when it can be;
/// one that cannot stays selectable as typed, so opening the screen never
/// silently drops it.
class VehicleColorDropdown extends StatelessWidget {
  const VehicleColorDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final raw = value?.trim() ?? '';
    final known = vehicleColorFor(raw);
    final legacy = raw.isNotEmpty && known == null ? raw : null;
    final selected = known?.key ?? legacy;

    return DropdownButtonFormField<String>(
      // Keyed on the value so a reload (e.g. after save) re-seeds it.
      key: ValueKey(selected),
      initialValue: selected,
      isExpanded: true,
      validator: validator,
      decoration: InputDecoration(
        labelText: l10n.vehicleColor,
        hintText: l10n.vehicleColorSelect,
        prefixIcon: const Icon(Icons.palette_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
      items: [
        for (final option in kVehicleColors)
          DropdownMenuItem(
            value: option.key,
            child: _ColorRow(
              swatch: option.swatch,
              label: vehicleColorName(l10n, option.key),
            ),
          ),
        if (legacy != null)
          DropdownMenuItem(
            value: legacy,
            child: _ColorRow(swatch: null, label: legacy),
          ),
      ],
      onChanged: (key) {
        if (key != null) onChanged(key);
      },
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.swatch, required this.label});

  final Color? swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: swatch ?? T.surfaceVariant(context),
            shape: BoxShape.circle,
            // White and silver vanish on a light sheet without an outline.
            border: Border.all(color: T.outline(context)),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
