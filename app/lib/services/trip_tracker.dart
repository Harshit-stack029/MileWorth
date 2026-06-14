import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/polyline.dart';

/// Records a single drive: accumulates distance from the GPS stream and
/// detects when the vehicle has stopped.
///
/// Sprint 2 scope: foreground tracking with manual start/stop (testable on a
/// real device). Fully-automatic background detection (activity recognition +
/// Android foreground service) is the remaining piece — see [autoModeNote].
class TripTracker extends ChangeNotifier {
  static const autoModeNote =
      'Automatic background start/stop needs an Android foreground service + '
      'activity recognition; foreground manual tracking is wired here first.';

  // Ignore tiny GPS jitter while parked (meters).
  static const double _minStepMeters = 8;
  // Consider the drive ended after this long below the moving threshold.
  static const Duration _stopAfter = Duration(minutes: 5);
  static const double _movingSpeedMps = 1.4; // ~5 km/h, faster than walking idle
  // Persist the in-progress drive to disk at most every this many meters so it
  // survives the OS killing the app mid-drive (FR-1 reliability).
  static const double _persistEveryMeters = 50;
  static const String _activeKey = 'active_trip_v1';

  StreamSubscription<Position>? _sub;
  Position? _last;
  DateTime? _startedAt;
  Timer? _stopTimer;

  bool tracking = false;
  double distanceMeters = 0;
  final List<Position> route = [];
  // Snapshot bookkeeping for crash-recovery persistence.
  double _lastPersistMeters = 0;
  double? _startLat, _startLng, _lastLat, _lastLng;
  DateTime? _lastFixAt;

  double get distanceMiles => distanceMeters / 1609.344;

  /// Ensures location services + permission. Returns false if unavailable so
  /// the UI can prompt the user (we never silently fail to track).
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Stricter check for background auto-detection: requires "Allow all the
  /// time". Calling requestPermission again prompts the user to upgrade from
  /// while-in-use to always on Android.
  Future<bool> ensureBackgroundPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always;
  }

  Future<bool> start() async {
    if (tracking) return true;
    if (!await ensurePermission()) return false;

    _reset();
    tracking = true;
    _startedAt = DateTime.now();
    _persist(); // record the session immediately so a quick kill still recovers

    _sub = Geolocator.getPositionStream(
      locationSettings: _recordingSettings(),
    ).listen(_onPosition);

    notifyListeners();
    return true;
  }

  /// High-accuracy recording. On Android we attach a foreground-service
  /// notification so the OS keeps the GPS stream alive while the app is
  /// backgrounded (required for "works while the app is closed").
  LocationSettings _recordingSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MileWorth is tracking your drive',
          notificationText: 'Recording mileage for your tax deductions',
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        // Keep the GPS stream alive while the app is backgrounded so trips
        // are recorded even when the app is not in the foreground.
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  void _onPosition(Position pos) {
    route.add(pos);
    _lastFixAt = DateTime.now();
    _lastLat = pos.latitude;
    _lastLng = pos.longitude;
    _startLat ??= pos.latitude;
    _startLng ??= pos.longitude;
    if (_last == null) {
      _last = pos;
    } else {
      final step = Geolocator.distanceBetween(
        _last!.latitude, _last!.longitude, pos.latitude, pos.longitude,
      );
      if (step >= _minStepMeters) {
        distanceMeters += step;
        _last = pos;
        // Throttled snapshot so an app kill loses at most ~50m of the drive.
        if (distanceMeters - _lastPersistMeters >= _persistEveryMeters) {
          _persist();
        }
        notifyListeners();
      }
      // Below the jitter threshold: keep the existing anchor so slow, stop-and-go
      // movement accumulates toward the threshold instead of being silently
      // dropped (which undercounted tax mileage on city/slow drives).
    }

    final moving = pos.speed >= _movingSpeedMps;
    if (moving) {
      _stopTimer?.cancel();
      _stopTimer = null;
    } else {
      // Arm an auto-stop if we stay still long enough.
      _stopTimer ??= Timer(_stopAfter, () => onAutoStop?.call());
    }
  }

  /// Invoked when the tracker has been stationary past [_stopAfter].
  VoidCallback? onAutoStop;

  /// Stop tracking and return the recorded trip as an API payload, or null if
  /// the drive was too short to record.
  Map<String, dynamic>? stop() {
    if (!tracking) return null;
    final start = _startedAt;
    final end = DateTime.now();
    _sub?.cancel();
    _stopTimer?.cancel();
    tracking = false;
    notifyListeners();

    if (start == null || distanceMiles < 0.1 || route.length < 2) {
      _reset();
      return null;
    }

    // Compress the recorded fixes into an encoded polyline so the route can be
    // drawn on the trip detail map. Downsampled to keep the stored string
    // bounded on long drives (the stream emits a fix every ~5m).
    final encoded = encodePolyline(downsample(
      [for (final p in route) RoutePoint(p.latitude, p.longitude)],
    ));

    final payload = {
      'startTime': start.toUtc().toIso8601String(),
      'endTime': end.toUtc().toIso8601String(),
      'distance': double.parse(distanceMiles.toStringAsFixed(2)),
      'category': 'uncategorized',
      'startLat': route.first.latitude,
      'startLng': route.first.longitude,
      'endLat': route.last.latitude,
      'endLng': route.last.longitude,
      if (encoded.isNotEmpty) 'routePolyline': encoded,
    };
    _reset(); // also clears the on-disk snapshot
    return payload;
  }

  // --- Crash-recovery persistence (Task 10) ---

  /// Write a compact snapshot of the in-progress drive to disk. Only the fields
  /// needed to rebuild a trip payload are stored (not the full route), so writes
  /// stay cheap.
  Future<void> _persist() async {
    _lastPersistMeters = distanceMeters;
    final start = _startedAt;
    if (start == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, jsonEncode({
      'startedAt': start.toUtc().toIso8601String(),
      'lastFixAt': (_lastFixAt ?? start).toUtc().toIso8601String(),
      'distanceMeters': distanceMeters,
      'samples': route.length,
      'startLat': _startLat,
      'startLng': _startLng,
      'lastLat': _lastLat,
      'lastLng': _lastLng,
    }));
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }

  /// If the app was killed mid-drive, rebuild that drive as a finished trip
  /// payload (ending at the last GPS fix) and clear the snapshot. Returns null
  /// when there's nothing to recover or the drive was too short. Skipped while a
  /// live recording is active so we never double-count.
  Future<Map<String, dynamic>?> recoverInterruptedTrip() async {
    if (tracking) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    if (raw == null || raw.isEmpty) return null;
    await prefs.remove(_activeKey);

    try {
      final s = jsonDecode(raw) as Map<String, dynamic>;
      final miles = (s['distanceMeters'] as num).toDouble() / 1609.344;
      final samples = (s['samples'] as num?)?.toInt() ?? 0;
      if (miles < 0.1 || samples < 2) return null;
      return {
        'startTime': s['startedAt'],
        'endTime': s['lastFixAt'],
        'distance': double.parse(miles.toStringAsFixed(2)),
        'category': 'uncategorized',
        'startLat': s['startLat'],
        'startLng': s['startLng'],
        'endLat': s['lastLat'],
        'endLng': s['lastLng'],
      };
    } catch (_) {
      return null; // corrupt snapshot — drop it
    }
  }

  void _reset() {
    distanceMeters = 0;
    route.clear();
    _last = null;
    _startedAt = null;
    _stopTimer?.cancel();
    _stopTimer = null;
    _lastPersistMeters = 0;
    _startLat = _startLng = _lastLat = _lastLng = null;
    _lastFixAt = null;
    _clearPersisted();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stopTimer?.cancel();
    super.dispose();
  }
}
