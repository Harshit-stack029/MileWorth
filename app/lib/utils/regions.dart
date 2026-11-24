/// Per-country defaults for the deduction math: currency, distance unit and
/// the official standard mileage rate where a government publishes one.
///
/// Rates change yearly (sometimes mid-year) — review this table at least once
/// a year. Countries with no official per-distance rate get `rate: 0`, and the
/// UI asks the user to enter their own.
library;

enum DistanceUnit { mi, km }

const double kmPerMile = 1.609344;

class RegionPreset {
  final String code; // ISO 3166-1 alpha-2, upper case
  final String name;
  final String currency; // ISO 4217
  final DistanceUnit unit;

  /// Official rate per [unit] in [currency]; 0 when none is published.
  final double rate;

  /// Where [rate] comes from, shown in Settings so users can check it.
  final String? rateSource;

  const RegionPreset(
    this.code,
    this.name,
    this.currency,
    this.unit, {
    this.rate = 0,
    this.rateSource,
  });

  bool get hasOfficialRate => rate > 0;
}

// Official rates, last reviewed Nov 2026.
const _withRates = <RegionPreset>[
  RegionPreset('US', 'United States', 'USD', DistanceUnit.mi,
      rate: 0.725, rateSource: 'IRS business rate, 2026'),
  RegionPreset('GB', 'United Kingdom', 'GBP', DistanceUnit.mi,
      rate: 0.55, rateSource: 'HMRC approved rate, first 10,000 mi, 2026-27'),
  RegionPreset('CA', 'Canada', 'CAD', DistanceUnit.km,
      rate: 0.73, rateSource: 'CRA allowance rate, first 5,000 km, 2026'),
  RegionPreset('AU', 'Australia', 'AUD', DistanceUnit.km,
      rate: 0.88, rateSource: 'ATO cents per km, 2025-26'),
  RegionPreset('DE', 'Germany', 'EUR', DistanceUnit.km,
      rate: 0.30, rateSource: 'Business travel (Dienstreise) rate'),
];

// Supported regions without a published per-distance rate: the currency and
// unit are set, and the user enters the rate their tax adviser uses.
const _withoutRates = <RegionPreset>[
  RegionPreset('IN', 'India', 'INR', DistanceUnit.km),
  RegionPreset('IE', 'Ireland', 'EUR', DistanceUnit.km),
  RegionPreset('FR', 'France', 'EUR', DistanceUnit.km),
  RegionPreset('ES', 'Spain', 'EUR', DistanceUnit.km),
  RegionPreset('IT', 'Italy', 'EUR', DistanceUnit.km),
  RegionPreset('NL', 'Netherlands', 'EUR', DistanceUnit.km),
  RegionPreset('NZ', 'New Zealand', 'NZD', DistanceUnit.km),
  RegionPreset('SG', 'Singapore', 'SGD', DistanceUnit.km),
  RegionPreset('MY', 'Malaysia', 'MYR', DistanceUnit.km),
  RegionPreset('AE', 'United Arab Emirates', 'AED', DistanceUnit.km),
  RegionPreset('SA', 'Saudi Arabia', 'SAR', DistanceUnit.km),
  RegionPreset('PK', 'Pakistan', 'PKR', DistanceUnit.km),
  RegionPreset('BD', 'Bangladesh', 'BDT', DistanceUnit.km),
  RegionPreset('LK', 'Sri Lanka', 'LKR', DistanceUnit.km),
  RegionPreset('NP', 'Nepal', 'NPR', DistanceUnit.km),
  RegionPreset('ZA', 'South Africa', 'ZAR', DistanceUnit.km),
  RegionPreset('NG', 'Nigeria', 'NGN', DistanceUnit.km),
  RegionPreset('KE', 'Kenya', 'KES', DistanceUnit.km),
  RegionPreset('PH', 'Philippines', 'PHP', DistanceUnit.km),
  RegionPreset('ID', 'Indonesia', 'IDR', DistanceUnit.km),
  RegionPreset('JP', 'Japan', 'JPY', DistanceUnit.km),
  RegionPreset('BR', 'Brazil', 'BRL', DistanceUnit.km),
  RegionPreset('MX', 'Mexico', 'MXN', DistanceUnit.km),
];

/// Every supported region, sorted by name for pickers.
final List<RegionPreset> allRegions = [..._withRates, ..._withoutRates]
  ..sort((a, b) => a.name.compareTo(b.name));

final Map<String, RegionPreset> _byCode = {
  for (final r in allRegions) r.code: r,
};

/// Preset for an ISO country code (any case), or null if unsupported.
RegionPreset? regionFor(String? code) {
  if (code == null) return null;
  return _byCode[code.trim().toUpperCase()];
}

/// Default when nothing is detected: the app's original US behaviour.
final RegionPreset defaultRegion = regionFor('US')!;

DistanceUnit unitFromName(String? name) =>
    name == 'km' ? DistanceUnit.km : DistanceUnit.mi;

/// Trips are stored in miles; convert for display/math in [unit].
double milesTo(DistanceUnit unit, double miles) =>
    unit == DistanceUnit.km ? miles * kmPerMile : miles;

/// Convert a distance the user typed in [unit] back to stored miles.
double toMiles(DistanceUnit unit, double value) =>
    unit == DistanceUnit.km ? value / kmPerMile : value;
