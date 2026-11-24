import '../utils/regions.dart';

/// Local app preferences. MileWorth has no accounts — this just holds the
/// settings that affect deduction math and display (rate, currency, distance
/// unit, region, weekend classification). Kept as a small immutable value so
/// the UI can `watch` it.
class AppUser {
  final double mileageRate;
  final String currency;
  final bool classifyWeekendsAsPersonal;

  /// Unit the rate is quoted in and distances are shown in. Trips are always
  /// stored in miles; see [milesTo] / [toMiles].
  final DistanceUnit distanceUnit;

  /// ISO country the current currency/unit/rate came from (null = never set).
  final String? regionCountry;

  /// True: follow the detected country. False: the user picked a region.
  final bool regionAuto;

  AppUser({
    required this.mileageRate,
    required this.currency,
    required this.classifyWeekendsAsPersonal,
    this.distanceUnit = DistanceUnit.mi,
    this.regionCountry,
    this.regionAuto = true,
  });

  RegionPreset? get region => regionFor(regionCountry);
}
