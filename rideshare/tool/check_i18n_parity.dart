// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Verifies app_en.arb and app_ar.arb have identical key sets and non-empty values.
void main() {
  final enFile = File('lib/l10n/app_en.arb');
  final arFile = File('lib/l10n/app_ar.arb');

  if (!enFile.existsSync() || !arFile.existsSync()) {
    stderr.writeln('ARB files not found under lib/l10n/');
    exit(1);
  }

  final enKeys = _messageKeys(enFile);
  final arKeys = _messageKeys(arFile);

  final onlyEn = enKeys.difference(arKeys).toList()..sort();
  final onlyAr = arKeys.difference(enKeys).toList()..sort();

  var failed = false;

  if (onlyEn.isNotEmpty) {
    failed = true;
    stderr.writeln('Keys in app_en.arb missing from app_ar.arb:');
    for (final key in onlyEn) {
      stderr.writeln('  - $key');
    }
  }

  if (onlyAr.isNotEmpty) {
    failed = true;
    stderr.writeln('Keys in app_ar.arb missing from app_en.arb:');
    for (final key in onlyAr) {
      stderr.writeln('  - $key');
    }
  }

  for (final key in enKeys.intersection(arKeys)) {
    final enValue = _messageValue(enFile, key);
    final arValue = _messageValue(arFile, key);
    if (enValue.trim().isEmpty) {
      failed = true;
      stderr.writeln('Empty EN value for key: $key');
    }
    if (arValue.trim().isEmpty) {
      failed = true;
      stderr.writeln('Empty AR value for key: $key');
    }
  }

  if (failed) {
    exit(1);
  }

  print(
    'i18n parity OK: ${enKeys.length} keys matched between app_en.arb and app_ar.arb',
  );
}

Set<String> _messageKeys(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((key) => !key.startsWith('@')).toSet();
}

String _messageValue(File file, String key) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final value = json[key];
  return value is String ? value : '';
}
