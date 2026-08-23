/// Phone number validation and normalization utilities.
class PhoneNumberUtils {
  /// Removes non-digit characters and normalizes the input to a 10-digit string
  /// if it represents a valid Indian mobile number format.
  static String normalizeIndianMobileNumber(String raw) {
    // Remove all non-digits
    final String digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return '';
    }

    final trimmedRaw = raw.trim();

    // Check if it starts with +91 or if the digits parse as a 12-digit number starting with 91
    if (trimmedRaw.startsWith('+91')) {
      if (digits.length == 12 && digits.startsWith('91')) {
        return digits.substring(2);
      }
    }

    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }

    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }

    return digits;
  }

  /// Checks if the supplied number is a valid 10-digit Indian mobile number
  /// (must start with 6, 7, 8, or 9 after normalization).
  static bool isValidIndianMobileNumber(String raw) {
    final normalized = normalizeIndianMobileNumber(raw);
    if (normalized.length != 10) {
      return false;
    }
    final firstDigit = normalized[0];
    return firstDigit == '6' || firstDigit == '7' || firstDigit == '8' || firstDigit == '9';
  }

  /// Appends the country code to a valid normalized 10-digit Indian mobile number
  /// to output it in E.164 format. Throws ArgumentError if input is invalid.
  static String toE164(String normalized10Digit) {
    // We should only accept exactly 10 digits starting with 6, 7, 8, 9
    final cleaned = normalized10Digit.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10 || !isValidIndianMobileNumber(cleaned)) {
      throw ArgumentError('Invalid normalized Indian mobile number: $normalized10Digit');
    }
    return '+91$cleaned';
  }
}
