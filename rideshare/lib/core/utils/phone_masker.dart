/// Utility class for masking phone numbers in text
class PhoneMasker {
  // Pattern to match phone numbers (supports various formats)
  // Matches: +201234567890, 01234567890, 1234567890, etc.
  static final RegExp _phonePattern = RegExp(
    r'(\+?\d{1,4}[\s-]?)?\(?\d{1,4}\)?[\s-]?\d{1,4}[\s-]?\d{1,9}',
    multiLine: false,
  );

  /// Masks phone numbers in the given text
  /// Replaces phone numbers with masked version (e.g., ***-***-XXXX)
  static String maskPhoneNumbers(String text) {
    if (text.isEmpty) return text;

    return text.replaceAllMapped(_phonePattern, (match) {
      final phoneNumber = match.group(0)!;
      final length = phoneNumber.length;
      
      // If it's a short number (less than 7 digits), mask completely
      if (length < 7) {
        return '*' * length;
      }
      
      // For longer numbers, show only last 4 digits
      // Format: XXX-XXX-XXXX or similar
      final last4 = phoneNumber.substring(length - 4);
      final masked = '*' * (length - 4);
      
      // Try to preserve the format if it has separators
      if (phoneNumber.contains('-') || phoneNumber.contains(' ')) {
        // Count separators in original
        final separators = phoneNumber.split(RegExp(r'\d')).where((s) => s.isNotEmpty).toList();
        if (separators.isNotEmpty) {
          // Simple masking: show format but mask numbers
          return masked + separators.join('') + last4;
        }
      }
      
      return masked + last4;
    });
  }

  /// Checks if text contains phone numbers
  static bool containsPhoneNumber(String text) {
    return _phonePattern.hasMatch(text);
  }

  /// Removes phone numbers from text completely
  static String removePhoneNumbers(String text) {
    return text.replaceAll(_phonePattern, '***');
  }
}



