import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mileworth/services/trip_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> snapshot({double meters = 4000, int samples = 20}) => {
        'startedAt': '2026-06-09T10:00:00.000Z',
        'lastFixAt': '2026-06-09T10:20:00.000Z',
        'distanceMeters': meters,
        'samples': samples,
        'startLat': 37.1,
        'startLng': -122.1,
        'lastLat': 37.2,
        'lastLng': -122.2,
      };

  test('recovers an interrupted drive into a trip payload and clears it', () async {
    SharedPreferences.setMockInitialValues({'active_trip_v1': jsonEncode(snapshot())});
    final tracker = TripTracker();

    final payload = await tracker.recoverInterruptedTrip();
    expect(payload, isNotNull);
    expect(payload!['startTime'], '2026-06-09T10:00:00.000Z');
    expect(payload['endTime'], '2026-06-09T10:20:00.000Z');
    expect(payload['category'], 'uncategorized');
    expect(payload['distance'], closeTo(4000 / 1609.344, 0.01));
    expect(payload['startLat'], 37.1);
    expect(payload['endLng'], -122.2);

    // Snapshot consumed: a second call recovers nothing.
    expect(await tracker.recoverInterruptedTrip(), isNull);
  });

  test('ignores a too-short interrupted drive', () async {
    SharedPreferences.setMockInitialValues(
        {'active_trip_v1': jsonEncode(snapshot(meters: 50, samples: 1))});
    final tracker = TripTracker();
    expect(await tracker.recoverInterruptedTrip(), isNull);
  });

  test('returns null when there is nothing to recover', () async {
    SharedPreferences.setMockInitialValues({});
    final tracker = TripTracker();
    expect(await tracker.recoverInterruptedTrip(), isNull);
  });
}
