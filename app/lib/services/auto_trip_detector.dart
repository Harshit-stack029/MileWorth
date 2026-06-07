import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trip_tracker.dart';

/// Watches for the start of a drive and automatically begins/ends recording,
/// so the user never taps a button (FR-1).
///
/// Battery strategy (NFR): while idle it runs a *low-power* sentinel stream
/// (coarse accuracy, large distance filter) that only wakes up on significant
/// movement. Real driving speed sustained for a few samples promotes it to the
/// high-accuracy [TripTracker] recording (which runs a foreground service).
/// When the tracker auto-stops, we fall back to the sentinel.
///
/// The ACTIVITY_RECOGNITION permission is declared so this speed heuristic can
/// later be replaced by true activity-recognition events without manifest churn.
class AutoTripDetector extends ChangeNotifier {
  AutoTripDetector(this._tracker, {required this.onTripComplete});

  final TripTracker _tracker;

  /// Persist a completed auto-detected trip (wired to AppState.addTrip).
  final Future<void> Function(Map<String, dynamic> payload) onTripComplete;

  static const _prefsKey = 'auto_tracking_enabled';
  // Sustained speed (m/s) that looks like driving rather than walking/cycling.
  static const double _driveSpeedMps = 5.5; // ~20 km/h
  // Consecutive moving samples before we commit to recording (avoids false starts).
  static const int _confirmSamples = 3;

  bool enabled = false;
  bool _recording = false;
  StreamSubscription<Position>? _sentinel;
  int _movingStreak = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_prefsKey) ?? false;
    if (enabled) await _startSentinel();
    notifyListeners();
  }

  Future<bool> setEnabled(bool value) async {
    if (value) {
      // Background auto-detection needs "Allow all the time".
      final ok = await _tracker.ensureBackgroundPermission();
      if (!ok) return false;
      await _startSentinel();
    } else {
      await _stopSentinel();
      if (_tracker.tracking) await _finishDrive();
    }
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    notifyListeners();
    return true;
  }

  Future<void> _startSentinel() async {
    await _sentinel?.cancel();
    _movingStreak = 0;
    _sentinel = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 50,
      ),
    ).listen(_onSentinel);
  }

  Future<void> _stopSentinel() async {
    await _sentinel?.cancel();
    _sentinel = null;
  }

  void _onSentinel(Position pos) {
    if (_recording) return;
    if (pos.speed >= _driveSpeedMps) {
      _movingStreak++;
      if (_movingStreak >= _confirmSamples) {
        _beginDrive();
      }
    } else {
      _movingStreak = 0;
    }
  }

  Future<void> _beginDrive() async {
    _recording = true;
    await _stopSentinel();
    _tracker.onAutoStop = _finishDrive; // tracker fires this after a stop
    final started = await _tracker.start();
    if (!started) {
      // Couldn't start (permission/service revoked) — fall back to sentinel.
      _recording = false;
      if (enabled) await _startSentinel();
    }
    notifyListeners();
  }

  Future<void> _finishDrive() async {
    final payload = _tracker.stop();
    _recording = false;
    _tracker.onAutoStop = null;
    if (payload != null) {
      await onTripComplete(payload);
    }
    if (enabled) await _startSentinel();
    notifyListeners();
  }

  @override
  void dispose() {
    _sentinel?.cancel();
    super.dispose();
  }
}
