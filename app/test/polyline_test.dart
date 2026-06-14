import 'package:flutter_test/flutter_test.dart';
import 'package:mileworth/utils/polyline.dart';

void main() {
  group('encodePolyline', () {
    test('matches the canonical Google example', () {
      // Reference vector from Google's polyline algorithm documentation.
      final points = [
        const RoutePoint(38.5, -120.2),
        const RoutePoint(40.7, -120.95),
        const RoutePoint(43.252, -126.453),
      ];
      expect(encodePolyline(points), r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    });

    test('returns empty for fewer than two points', () {
      expect(encodePolyline([const RoutePoint(38.5, -120.2)]), '');
      expect(encodePolyline(const []), '');
    });
  });

  group('decodePolyline', () {
    test('round-trips an encoded route within 1e-5 precision', () {
      final original = [
        const RoutePoint(37.4219983, -122.084),
        const RoutePoint(37.4221, -122.0835),
        const RoutePoint(37.4225, -122.0828),
      ];
      final decoded = decodePolyline(encodePolyline(original));
      expect(decoded.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(decoded[i].lat, closeTo(original[i].lat, 1e-5));
        expect(decoded[i].lng, closeTo(original[i].lng, 1e-5));
      }
    });

    test('returns empty for empty or corrupt input', () {
      expect(decodePolyline(''), isEmpty);
      expect(decodePolyline('!!!incomplete'), isEmpty);
    });
  });

  group('downsample', () {
    test('leaves short routes untouched', () {
      final pts = List.generate(10, (i) => RoutePoint(i.toDouble(), 0));
      expect(downsample(pts, maxPoints: 100), hasLength(10));
    });

    test('caps long routes and always keeps first and last', () {
      final pts = List.generate(5000, (i) => RoutePoint(i.toDouble(), 0));
      final out = downsample(pts, maxPoints: 1000);
      expect(out.length, lessThanOrEqualTo(1001));
      expect(out.first.lat, 0);
      expect(out.last.lat, 4999);
    });
  });
}
