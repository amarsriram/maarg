import 'package:intl/intl.dart';

class CurrencyUtils {
  static String formatINR(dynamic amount) {
    if (amount == null) return '₹0';
    double parsedAmount;
    if (amount is int) {
      parsedAmount = amount.toDouble();
    } else if (amount is double) {
      parsedAmount = amount;
    } else if (amount is String) {
      parsedAmount = double.tryParse(amount) ?? 0.0;
    } else {
      parsedAmount = 0.0;
    }

    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return format.format(parsedAmount);
  }
}
