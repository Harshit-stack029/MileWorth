import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../models/insights.dart';
import '../models/summary.dart';
import '../models/trip.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/outbox.dart';
import '../services/storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Single source of truth for auth + trip data. Backed by [ApiClient].
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, TokenStorage? storage, Outbox? outbox})
      : _api = api ?? ApiClient(),
        _storage = storage ?? TokenStorage(),
        _outbox = outbox ?? Outbox();

  final ApiClient _api;
  final TokenStorage _storage;
  final Outbox _outbox;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  List<Trip> trips = [];
  List<Expense> expenses = [];
  TripSummary summary = TripSummary.empty();
  int pendingSync = 0;
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
    expenses = [];
    summary = TripSummary.empty();
    pendingSync = 0;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Reload trips + dashboard summary. Also flushes any offline queue first.
  Future<void> refresh() async {
    _setLoading(true);
    try {
      await flushOutbox();
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

  /// Create a trip. If the device is offline the write is queued and synced
  /// later (FR-13). Validation/HTTP errors (ApiException) are NOT queued —
  /// they're surfaced to the caller.
  Future<void> addTrip(Map<String, dynamic> payload) async {
    try {
      await _api.post('/trips', payload);
    } on ApiException {
      rethrow;
    } catch (_) {
      await _outbox.enqueue('/trips', payload);
      pendingSync = await _outbox.count();
      notifyListeners();
      return;
    }
    await refresh();
  }

  /// Push any queued offline writes. Safe to call often; no-op when empty.
  Future<void> flushOutbox() async {
    final sent = await _outbox.flush((path, body) => _api.post(path, body));
    pendingSync = await _outbox.count();
    if (sent > 0) notifyListeners();
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

  // --- Expenses (Sprint 3) ---

  Future<void> fetchExpenses() async {
    final res = await _api.get('/expenses');
    expenses = (res['expenses'] as List)
        .map((j) => Expense.fromJson(j as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> addExpense(Map<String, dynamic> payload) async {
    await _api.post('/expenses', payload);
    await fetchExpenses();
  }

  Future<void> deleteExpense(Expense expense) async {
    await _api.delete('/expenses/${expense.id}');
    await fetchExpenses();
  }

  // --- Reports (Sprint 3) ---

  /// Totals for a date range, shown before exporting.
  Future<Map<String, dynamic>> reportSummary(DateTime from, DateTime to) async {
    final res = await _api.get(
      '/reports/summary?from=${_d(from)}&to=${_d(to)}',
    );
    return Map<String, dynamic>.from(res['summary'] as Map);
  }

  /// Download a generated report. format = 'pdf' | 'csv'.
  Future<Uint8List> downloadReport({
    required String format,
    required DateTime from,
    required DateTime to,
  }) {
    return _api.getBytes('/reports?format=$format&from=${_d(from)}&to=${_d(to)}');
  }

  String _d(DateTime d) => d.toIso8601String().substring(0, 10);

  // --- Insights (Sprint 4) ---

  Future<Insights> fetchInsights() async {
    final res = await _api.get('/trips/insights');
    return Insights.fromJson(Map<String, dynamic>.from(res['insights'] as Map));
  }

  // --- Subscription (Sprint 4) ---

  /// Activate Pro after a Play Billing purchase. In production the backend
  /// verifies [purchaseToken] with Google before flipping the status.
  Future<void> verifySubscription({
    required String purchaseToken,
    required String productId,
  }) async {
    final res = await _api.post('/billing/verify', {
      'purchaseToken': purchaseToken,
      'productId': productId,
    });
    user = AppUser.fromJson(res['user']);
    notifyListeners();
  }

  Future<void> updateSettings({
    double? mileageRate,
    String? currency,
    bool? classifyWeekendsAsPersonal,
  }) async {
    final res = await _api.patch('/auth/me/settings', {
      'mileageRate': ?mileageRate,
      'currency': ?currency,
      'classifyWeekendsAsPersonal': ?classifyWeekendsAsPersonal,
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
