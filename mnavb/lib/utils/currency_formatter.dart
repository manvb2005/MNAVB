import 'package:intl/intl.dart';

final NumberFormat _moneyNumberFormat = NumberFormat('#,##0.00', 'en_US');

String formatAmount(num? amount) {
  return _moneyNumberFormat.format((amount ?? 0).toDouble());
}

String formatMoney(num? amount, {String symbol = 'S/'}) {
  return '$symbol ${formatAmount(amount)}';
}
