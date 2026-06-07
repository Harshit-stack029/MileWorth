import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A persistent queue of API writes that failed because the device was offline
/// (FR-13). Each entry is { "path": "/trips", "body": {...} }. On reconnect the
/// queue is flushed in order.
class Outbox {
  static const _key = 'outbox_v1';

  Future<List<Map<String, dynamic>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _write(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }

  Future<int> count() async => (await _read()).length;

  Future<void> enqueue(String path, Map<String, dynamic> body) async {
    final items = await _read();
    items.add({'path': path, 'body': body});
    await _write(items);
  }

  /// Try to send each queued item via [send]. Items that still fail stay queued
  /// (in order); successfully sent items are removed. Returns how many were sent.
  Future<int> flush(Future<void> Function(String path, Map<String, dynamic> body) send) async {
    final items = await _read();
    if (items.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var sent = 0;
    for (final item in items) {
      if (remaining.isNotEmpty) {
        // Preserve ordering: once one fails, keep the rest queued.
        remaining.add(item);
        continue;
      }
      try {
        await send(item['path'] as String, Map<String, dynamic>.from(item['body'] as Map));
        sent++;
      } catch (_) {
        remaining.add(item);
      }
    }
    await _write(remaining);
    return sent;
  }
}
