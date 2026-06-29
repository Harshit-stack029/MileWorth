/// Local app preferences. MileWorth has no accounts — this just holds the
/// settings that affect deduction math and display (rate, currency, weekend
/// classification). Kept as a small immutable value so the UI can `watch` it.
class AppUser {
  final double mileageRate;
  final String currency;
  final bool classifyWeekendsAsPersonal;

  AppUser({
    required this.mileageRate,
    required this.currency,
    required this.classifyWeekendsAsPersonal,
  });
}
