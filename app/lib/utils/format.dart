import 'package:intl/intl.dart';

String formatMoney(double amount, String currency) {
  final symbol = _currencySymbol(currency);
  return NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(amount);
}

String formatMiles(double miles) => '${miles.toStringAsFixed(1)} mi';

String formatDateTime(DateTime dt) => DateFormat('MMM d, h:mm a').format(dt.toLocal());

String formatDate(DateTime dt) => DateFormat('MMM d, y').format(dt.toLocal());

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _currencySymbol(String currency) {
  switch (currency) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'CAD':
      return 'CA\$';
    case 'AUD':
      return 'A\$';
    default:
      return '$currency ';
  }
}
