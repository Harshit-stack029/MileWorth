import 'package:flutter_test/flutter_test.dart';
import 'package:mileworth/utils/navigation_launcher.dart';

void main() {
  const lat = 37.42796133580664;
  const lng = -122.085749655962;

  test('android link uses the turn-by-turn navigation scheme', () {
    final uri = DirectionsLinks.androidNavigation(lat, lng);
    // google.navigation: starts guidance immediately; a plain geo: link would
    // only drop a pin, which is not "navigate".
    expect(uri.scheme, 'google.navigation');
    expect(uri.toString(), contains('$lat,$lng'));
    expect(uri.toString(), contains('mode=d'));
  });

  test('ios link targets Apple Maps with driving directions', () {
    final uri = DirectionsLinks.appleMaps(lat, lng);
    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters['daddr'], '$lat,$lng');
    expect(uri.queryParameters['dirflg'], 'd');
  });

  test('universal link is a well-formed Google Maps directions URL', () {
    final uri = DirectionsLinks.universal(lat, lng);
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '$lat,$lng');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('candidates always end with the universal https fallback', () {
    // Whatever the platform, the last resort must be a link a browser can open,
    // so "Navigate" never dead-ends on a device without Google Maps.
    final candidates = DirectionsLinks.candidates(lat, lng);
    expect(candidates, isNotEmpty);
    expect(candidates.last, DirectionsLinks.universal(lat, lng));
  });

  test('negative and zero coordinates survive the round trip', () {
    // Southern/western hemispheres and the null island edge case.
    final uri = DirectionsLinks.universal(-33.8688, 151.2093);
    expect(uri.queryParameters['destination'], '-33.8688,151.2093');
    expect(
      DirectionsLinks.universal(0, 0).queryParameters['destination'],
      '0.0,0.0',
    );
  });
}
