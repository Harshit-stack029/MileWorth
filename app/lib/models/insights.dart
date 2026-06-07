class CategoryStat {
  final String category;
  final int count;
  final double miles;
  final double value;

  CategoryStat({
    required this.category,
    required this.count,
    required this.miles,
    required this.value,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) => CategoryStat(
        category: json['category'] as String? ?? 'uncategorized',
        count: (json['count'] as num?)?.toInt() ?? 0,
        miles: (json['miles'] as num?)?.toDouble() ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

class LocationStat {
  final String name;
  final int count;
  final double value;

  LocationStat({required this.name, required this.count, required this.value});

  factory LocationStat.fromJson(Map<String, dynamic> json) => LocationStat(
        name: json['name'] as String? ?? 'Unknown',
        count: (json['count'] as num?)?.toInt() ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

class Insights {
  final List<CategoryStat> byCategory;
  final List<LocationStat> topLocations;

  Insights({required this.byCategory, required this.topLocations});

  int get totalTrips => byCategory.fold(0, (s, c) => s + c.count);

  factory Insights.fromJson(Map<String, dynamic> json) => Insights(
        byCategory: (json['byCategory'] as List? ?? [])
            .map((j) => CategoryStat.fromJson(j as Map<String, dynamic>))
            .toList(),
        topLocations: (json['topLocations'] as List? ?? [])
            .map((j) => LocationStat.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
}
