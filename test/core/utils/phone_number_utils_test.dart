import 'package:flutter_test/flutter_test.dart';
import 'package:maarg/core/utils/phone_number_utils.dart';

void main() {
  group('PhoneNumberUtils Tests', () {
    group('Normalization', () {
      test('valid 10-digit number is unchanged', () {
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('9876543210'), '9876543210');
      });

      test('removes +91 prefix', () {
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('+919876543210'), '9876543210');
      });

      test('removes 91 prefix when length is 12', () {
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('919876543210'), '9876543210');
      });

      test('removes +91 prefix with spaces', () {
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('+91 98765 43210'), '9876543210');
      });

      test('removes leading 0 when length is 11', () {
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('09876543210'), '9876543210');
      });

      test('handles hyphens', () {
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('98765-43210'), '9876543210');
      });

      test('does not silently convert overlong numbers starting with 91', () {
        // 9198765432102 has 13 digits. Should not strip 91.
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('9198765432102'), '9198765432102');
      });

      test('does not silently convert overlong numbers starting with 0', () {
        // 098765432102 has 12 digits. Should not strip 0.
        expect(PhoneNumberUtils.normalizeIndianMobileNumber('098765432102'), '098765432102');
      });
    });

    group('Validation', () {
      test('valid forms', () {
        expect(PhoneNumberUtils.isValidIndianMobileNumber('9876543210'), isTrue);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('+919876543210'), isTrue);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('919876543210'), isTrue);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('+91 98765 43210'), isTrue);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('09876543210'), isTrue);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('98765-43210'), isTrue);
      });

      test('invalid forms', () {
        expect(PhoneNumberUtils.isValidIndianMobileNumber(''), isFalse);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('12345'), isFalse);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('123456789'), isFalse);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('1234567890'), isFalse); // starts with 1
        expect(PhoneNumberUtils.isValidIndianMobileNumber('5876543210'), isFalse); // starts with 5
        expect(PhoneNumberUtils.isValidIndianMobileNumber('alphabetic'), isFalse);
        expect(PhoneNumberUtils.isValidIndianMobileNumber('+929876543210'), isFalse); // malformed country code (+92)
        expect(PhoneNumberUtils.isValidIndianMobileNumber('9198765432102'), isFalse); // ambiguous/overlong
      });
    });

    group('E.164 Conversion', () {
      test('formats valid normalized numbers', () {
        expect(PhoneNumberUtils.toE164('9876543210'), '+919876543210');
        expect(PhoneNumberUtils.toE164(PhoneNumberUtils.normalizeIndianMobileNumber('+91 98765 43210')), '+919876543210');
        expect(PhoneNumberUtils.toE164(PhoneNumberUtils.normalizeIndianMobileNumber('919876543210')), '+919876543210');
        expect(PhoneNumberUtils.toE164(PhoneNumberUtils.normalizeIndianMobileNumber('09876543210')), '+919876543210');
      });

      test('throws ArgumentError on malformed numbers', () {
        expect(() => PhoneNumberUtils.toE164('12345'), throwsArgumentError);
        expect(() => PhoneNumberUtils.toE164('5876543210'), throwsArgumentError);
        expect(() => PhoneNumberUtils.toE164(''), throwsArgumentError);
      });
    });
  });
}
