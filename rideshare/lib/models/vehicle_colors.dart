import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// One choice in the vehicle colour list. [key] is what is stored on the
/// vehicle; the label is resolved per language, so a passenger reading in
/// English sees "White" for a car a driver saved in Arabic.
class VehicleColorOption {
  const VehicleColorOption(this.key, this.swatch, {this.aliases = const []});

  final String key;
  final Color swatch;

  /// Free-text names drivers typed before the list existed, so an old value
  /// still selects and translates.
  final List<String> aliases;
}

const List<VehicleColorOption> kVehicleColors = [
  VehicleColorOption('white', Color(0xFFFFFFFF), aliases: ['أبيض', 'ابيض']),
  VehicleColorOption('black', Color(0xFF111111), aliases: ['أسود', 'اسود']),
  VehicleColorOption('silver', Color(0xFFC0C4C8), aliases: ['فضي', 'فضّي']),
  VehicleColorOption(
    'gray',
    Color(0xFF7A7F85),
    aliases: ['رمادي', 'grey', 'رصاصي'],
  ),
  VehicleColorOption('red', Color(0xFFD32F2F), aliases: ['أحمر', 'احمر']),
  VehicleColorOption('blue', Color(0xFF1E5BB8), aliases: ['أزرق', 'ازرق']),
  VehicleColorOption('green', Color(0xFF2E7D32), aliases: ['أخضر', 'اخضر']),
  VehicleColorOption('beige', Color(0xFFD9C7A3), aliases: ['بيج']),
  VehicleColorOption('brown', Color(0xFF6D4C41), aliases: ['بني', 'بنّي']),
  VehicleColorOption('gold', Color(0xFFC9A227), aliases: ['ذهبي']),
  VehicleColorOption('yellow', Color(0xFFF4C430), aliases: ['أصفر', 'اصفر']),
  VehicleColorOption(
    'orange',
    Color(0xFFEF7D22),
    aliases: ['برتقالي', 'برتقالى'],
  ),
];

/// The listed colour a stored value names (its key or an old free-text
/// alias), or null for anything else.
VehicleColorOption? vehicleColorFor(String? value) {
  final v = value?.trim().toLowerCase();
  if (v == null || v.isEmpty) return null;
  for (final option in kVehicleColors) {
    if (option.key == v || option.aliases.contains(v)) return option;
  }
  return null;
}

String vehicleColorName(AppLocalizations l10n, String key) {
  switch (key) {
    case 'white':
      return l10n.vehicleColorWhite;
    case 'black':
      return l10n.vehicleColorBlack;
    case 'silver':
      return l10n.vehicleColorSilver;
    case 'gray':
      return l10n.vehicleColorGray;
    case 'red':
      return l10n.vehicleColorRed;
    case 'blue':
      return l10n.vehicleColorBlue;
    case 'green':
      return l10n.vehicleColorGreen;
    case 'beige':
      return l10n.vehicleColorBeige;
    case 'brown':
      return l10n.vehicleColorBrown;
    case 'gold':
      return l10n.vehicleColorGold;
    case 'yellow':
      return l10n.vehicleColorYellow;
    case 'orange':
      return l10n.vehicleColorOrange;
    default:
      return key;
  }
}

/// How a stored colour reads to the user: the translated name of a listed
/// colour, or an old free-text value as it was typed.
String vehicleColorLabel(AppLocalizations l10n, String value) {
  final option = vehicleColorFor(value);
  return option == null ? value : vehicleColorName(l10n, option.key);
}
