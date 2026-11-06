import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/utils/email_format.dart';

void main() {
  test('accepts an ordinary address, ignoring outer spaces', () {
    expect(isValidEmail('mohammad.khader@example.com'), isTrue);
    expect(isValidEmail(' mohammad@example.jo '), isTrue);
  });

  test('refuses what cannot be an address', () {
    for (final value in ['', 'mohammad', 'a@b', 'a b@example.com', '@x.com']) {
      expect(isValidEmail(value), isFalse, reason: value);
    }
  });
}
