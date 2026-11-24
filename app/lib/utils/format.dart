import 'package:intl/intl.dart';

import 'regions.dart';

/// Money in [currency] (ISO 4217) with its usual symbol: $, ₹, £, €, CA$ …
String formatMoney(double amount, String currency) {
  return NumberFormat.simpleCurrency(name: currency, decimalDigits: 2)
      .format(amount);
}

/// A stored distance (always miles) shown in the user's [unit].
String formatDistance(double miles, DistanceUnit unit) =>
    '${milesTo(unit, miles).toStringAsFixed(1)} ${unit.name}';

/// "Miles" / "Kilometres" for labels.
String distanceWord(DistanceUnit unit) =>
    unit == DistanceUnit.km ? 'Kilometres' : 'Miles';

/// "mile" / "km" for "per …" phrases.
String perUnit(DistanceUnit unit) => unit == DistanceUnit.km ? 'km' : 'mile';

String formatDateTime(DateTime dt) => DateFormat('MMM d, h:mm a').format(dt.toLocal());

String formatDate(DateTime dt) => DateFormat('MMM d, y').format(dt.toLocal());

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
