class TripSummary {
  final double totalMiles;
  final int totalTrips;
  final int businessTrips;
  final int uncategorizedTrips;
  final double totalDeductions;

  TripSummary({
    required this.totalMiles,
    required this.totalTrips,
    required this.businessTrips,
    required this.uncategorizedTrips,
    required this.totalDeductions,
  });

  factory TripSummary.empty() => TripSummary(
        totalMiles: 0,
        totalTrips: 0,
        businessTrips: 0,
        uncategorizedTrips: 0,
        totalDeductions: 0,
      );

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    return TripSummary(
      totalMiles: (json['totalMiles'] as num?)?.toDouble() ?? 0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      businessTrips: (json['businessTrips'] as num?)?.toInt() ?? 0,
      uncategorizedTrips: (json['uncategorizedTrips'] as num?)?.toInt() ?? 0,
      totalDeductions: (json['totalDeductions'] as num?)?.toDouble() ?? 0,
    );
  }
}
