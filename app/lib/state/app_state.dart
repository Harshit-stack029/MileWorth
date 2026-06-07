import 'package:flutter/foundation.dart';

import '../models/summary.dart';
import '../models/trip.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Single source of truth for auth + trip data. Backed by [ApiClient].
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, TokenStorage? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? TokenStorage();

  final ApiClient _api;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  List<Trip> trips = [];
  TripSummary summary = TripSummary.empty();
  bool loading = false;
  String? error;

  /// Called once at startup: restore a saved session if present.
  Future<void> bootstrap() async {
    final token = await _storage.read();
    if (token == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _api.setToken(token);
    try {
      final res = await _api.get('/auth/me');
      user = AppUser.fromJson(res['user']);
      status = AuthStatus.signedIn;
      notifyListeners();
      await refresh();
    } catch (_) {
      await signOut();
    }
  }

  Future<void> _authenticate(String path, String email, String password) async {
    _setLoading(true);
    try {
      final res = await _api.post(path, {'email': email, 'password': password});
      final token = res['token'] as String;
      await _storage.write(token);
      _api.setToken(token);
      user = AppUser.fromJson(res['user']);
      status = AuthStatus.signedIn;
      error = null;
      _setLoading(false);
      await refresh();
    } on ApiException catch (e) {
      error = e.message;
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> login(String email, String password) =>
      _authenticate('/auth/login', email, password);

  Future<void> register(String email, String password) =>
      _authenticate('/auth/register', email, password);

  Future<void> signOut() async {
    await _storage.clear();
    _api.setToken(null);
    user = null;
    trips = [];
    summary = TripSummary.empty();
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Reload trips + dashboard summary.
  Future<void> refresh() async {
    _setLoading(true);
    try {
      final tripsRes = await _api.get('/trips');
      trips = (tripsRes['trips'] as List)
          .map((j) => Trip.fromJson(j as Map<String, dynamic>))
          .toList();
      final summaryRes = await _api.get('/trips/summary');
      summary = TripSummary.fromJson(summaryRes['summary']);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addTrip(Map<String, dynamic> payload) async {
    await _api.post('/trips', payload);
    await refresh();
  }

  /// Reclassify a trip business <-> personal (FR-3).
  Future<void> setCategory(Trip trip, String category) async {
    await _api.patch('/trips/${trip.id}', {'category': category});
    await refresh();
  }

  Future<void> deleteTrip(Trip trip) async {
    await _api.delete('/trips/${trip.id}');
    await refresh();
  }

  Future<void> updateSettings({double? mileageRate, String? currency}) async {
    final res = await _api.patch('/auth/me/settings', {
      'mileageRate': ?mileageRate,
      'currency': ?currency,
    });
    user = AppUser.fromJson(res['user']);
    notifyListeners();
    await refresh(); // deduction totals depend on the rate
  }

  void _setLoading(bool v) {
    loading = v;
    notifyListeners();
  }
}
