/// Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits mapped back to
/// ASCII.
///
/// `intl` renders dates and times with the numbering system of the locale, so
/// an Arabic locale yields "٢٤ يوليو ٢٠٢٥". The designs use Western digits
/// throughout, so screens that follow them normalise the formatted string.
String toWesternDigits(String input) {
  if (input.isEmpty) return input;

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + (rune - 0x06F0));
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
