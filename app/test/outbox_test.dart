import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mileworth/services/outbox.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enqueue increments count and persists', () async {
    final outbox = Outbox();
    expect(await outbox.count(), 0);
    await outbox.enqueue('/trips', {'distance': 10});
    await outbox.enqueue('/trips', {'distance': 20});
    expect(await outbox.count(), 2);
  });

  test('flush sends all when send succeeds and empties the queue', () async {
    final outbox = Outbox();
    await outbox.enqueue('/trips', {'distance': 10});
    await outbox.enqueue('/trips', {'distance': 20});

    final sentBodies = <Map<String, dynamic>>[];
    final sent = await outbox.flush((path, body) async => sentBodies.add(body));

    expect(sent, 2);
    expect(await outbox.count(), 0);
    expect(sentBodies.map((b) => b['distance']), [10, 20]);
  });

  test('flush keeps items queued (in order) when send fails', () async {
    final outbox = Outbox();
    await outbox.enqueue('/trips', {'distance': 10});
    await outbox.enqueue('/trips', {'distance': 20});

    final sent = await outbox.flush((_, __) async => throw Exception('offline'));

    expect(sent, 0);
    expect(await outbox.count(), 2);
  });

  test('flush stops at first failure to preserve ordering', () async {
    final outbox = Outbox();
    await outbox.enqueue('/trips', {'n': 1});
    await outbox.enqueue('/trips', {'n': 2});
    await outbox.enqueue('/trips', {'n': 3});

    var calls = 0;
    final sent = await outbox.flush((_, __) async {
      calls++;
      if (calls == 2) throw Exception('drop');
    });

    // First sent, second failed -> third must not be attempted; 2 remain queued.
    expect(sent, 1);
    expect(calls, 2);
    expect(await outbox.count(), 2);
  });
}
