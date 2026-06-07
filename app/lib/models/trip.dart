class Trip {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final String category; // business | personal | uncategorized
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String? routePolyline;
  final double deductionValue;

  Trip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.category,
    required this.deductionValue,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.routePolyline,
  });

  Duration get duration => endTime.difference(startTime);

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['_id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      distance: (json['distance'] as num).toDouble(),
      category: json['category'] as String? ?? 'uncategorized',
      startLat: (json['startLat'] as num?)?.toDouble(),
      startLng: (json['startLng'] as num?)?.toDouble(),
      endLat: (json['endLat'] as num?)?.toDouble(),
      endLng: (json['endLng'] as num?)?.toDouble(),
      routePolyline: json['routePolyline'] as String?,
      deductionValue: (json['deductionValue'] as num?)?.toDouble() ?? 0,
    );
  }
}
