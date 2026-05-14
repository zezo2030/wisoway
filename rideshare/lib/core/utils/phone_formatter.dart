/// Formats an E.164-ish phone string for human display in left-to-right
/// reading order: `+CC NNN NNN NNNN`.
///
/// Examples:
///   `+201234567890`  -> `+20 123 456 7890`
///   `+96279123456`   -> `+962 79 123 456`
///   `0791234567`     -> `0791234567` (kept as-is when no country code)
String formatPhoneDisplay(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  if (!trimmed.startsWith('+')) {
    return trimmed;
  }

  final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return trimmed;

  // Country code = first 1-3 digits. Heuristic: 1 = NANP, 2-3 = others.
  int ccLen = 1;
  if (digits.length > 10) {
    ccLen = 3;
  } else if (digits.length > 7) {
    ccLen = 2;
  }
  if (ccLen >= digits.length) {
    return '+$digits';
  }

  final cc = digits.substring(0, ccLen);
  final rest = digits.substring(ccLen);

  final groups = <String>[];
  var remaining = rest;
  while (remaining.length > 4) {
    groups.add(remaining.substring(0, 3));
    remaining = remaining.substring(3);
  }
  if (remaining.isNotEmpty) groups.add(remaining);

  return '+$cc ${groups.join(' ')}';
}
