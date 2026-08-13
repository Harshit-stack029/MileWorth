import 'package:flutter_test/flutter_test.dart';
import 'package:mileworth/models/trip.dart';
import 'package:mileworth/utils/polyline.dart';
import 'package:mileworth/widgets/trip_route_map.dart';

Trip _trip({
  double? startLat,
  double? startLng,
  double? endLat,
  double? endLng,
  String? routePolyline,
}) {
  return Trip(
    id: 't1',
    startTime: DateTime(2026, 1, 1, 9),
    endTime: DateTime(2026, 1, 1, 10),
    distance: 12,
    category: 'business',
    deductionValue: 8,
    startLat: startLat,
    startLng: startLng,
    endLat: endLat,
    endLng: endLng,
    routePolyline: routePolyline,
  );
}

void main() {
  test('prefers the recorded polyline over bare endpoints', () {
    final encoded = encodePolyline([
      const RoutePoint(38.5, -120.2),
      const RoutePoint(40.7, -120.95),
      const RoutePoint(43.252, -126.453),
    ]);
    final points = tripRoutePoints(_trip(
      startLat: 1,
      startLng: 1,
      endLat: 2,
      endLng: 2,
      routePolyline: encoded,
    ));
    // The full route, not the two endpoints.
    expect(points.length, 3);
    expect(points.first.latitude, closeTo(38.5, 1e-5));
    expect(points.last.longitude, closeTo(-126.453, 1e-5));
  });

  test('falls back to start/end when there is no polyline', () {
    final points = tripRoutePoints(
      _trip(startLat: 10, startLng: 20, endLat: 30, endLng: 40),
    );
    expect(points.length, 2);
    expect(points.first.latitude, 10);
    expect(points.last.latitude, 30);
  });

  test('a manually entered trip yields no points', () {
    // Drives the "No route recorded" placeholder rather than an empty map.
    expect(tripRoutePoints(_trip()), isEmpty);
  });

  test('a single known endpoint still yields one point', () {
    expect(tripRoutePoints(_trip(startLat: 5, startLng: 6)).length, 1);
  });

  test('a corrupt polyline falls back instead of throwing', () {
    final points = tripRoutePoints(_trip(
      startLat: 10,
      startLng: 20,
      endLat: 30,
      endLng: 40,
      routePolyline: '!!!not-a-polyline!!!',
    ));
    expect(points.length, 2);
    expect(points.first.latitude, 10);
  });

  test('bounds enclose every point of the route', () {
    final bounds = boundsOf(
      tripRoutePoints(_trip(startLat: 10, startLng: 40, endLat: 30, endLng: 20)),
    );
    expect(bounds.southwest.latitude, 10);
    expect(bounds.southwest.longitude, 20);
    expect(bounds.northeast.latitude, 30);
    expect(bounds.northeast.longitude, 40);
  });
}
