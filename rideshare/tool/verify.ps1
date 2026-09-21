# CI verification: i18n parity, static analysis, and tests.
$ErrorActionPreference = "Stop"
dart run tool/check_i18n_parity.dart
flutter analyze
flutter test
