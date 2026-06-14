import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        _outbox = outbox ?? Outbox() {
    // Sign out automatically when the server rejects our token mid-session.
    _api.onUnauthorized = _handleSessionExpired;
  }

  bool _handlingExpiry = false;

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
  bool onboardingSeen = false;
  String? error;
  // One-shot message shown on the login screen after an automatic sign-out
  // (e.g. session expiry). Consumed + cleared by the UI.
  String? sessionMessage;

  static const _onboardingKey = 'onboarding_seen';
  static const _serverUrlKey = 'server_url';

  /// The backend URL currently in use (compile-time default unless overridden).
  String get serverUrl => _api.baseUrl;

  /// Override the backend URL at runtime (for test builds / switching servers).
  Future<void> setServerUrl(String url) async {
    _api.setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, _api.baseUrl);
    notifyListeners();
  }

  /// Called once at startup: restore a saved session if present.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(_onboardingKey) ?? false;
    final savedUrl = prefs.getString(_serverUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) _api.setBaseUrl(savedUrl);
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

  /// Mark first-run onboarding as completed so it never shows again.
  Future<void> completeOnboarding() async {
    onboardingSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> login(String email, String password) =>
      _authenticate('/auth/login', email, password);

  /// Request a password-reset email. Returns a dev-only token (non-production
  /// backends echo it back so the flow is testable without a mail provider);
  /// in production this is always null and the user gets the token by email.
  Future<String?> requestPasswordReset(String email) async {
    final res = await _api.post('/auth/forgot-password', {'email': email.trim()});
    return res is Map ? res['devToken'] as String? : null;
  }

  /// Complete a password reset with the emailed token; signs the user in.
  Future<void> resetPassword(String token, String password) async {
    final res = await _api.post('/auth/reset-password', {
      'token': token.trim(),
      'password': password,
    });
    final t = res['token'] as String;
    await _storage.write(t);
    _api.setToken(t);
    user = AppUser.fromJson(res['user']);
    status = AuthStatus.signedIn;
    error = null;
    notifyListeners();
    await refresh();
  }

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

  /// Re-send the email-verification message to the signed-in user. Returns a
  /// dev-only token (non-production echoes it back) or null in production.
  Future<String?> resendVerification() async {
    final res = await _api.post('/auth/me/resend-verification', {});
    return res is Map ? res['devToken'] as String? : null;
  }

  /// Confirm an email-verification token, then refresh the local user so the
  /// "verify your email" banner disappears.
  Future<void> verifyEmail(String token) async {
    final res = await _api.post('/auth/verify-email', {'token': token.trim()});
    user = AppUser.fromJson(res['user']);
    notifyListeners();
  }

  /// Re-fetch the current user (e.g. to pick up server-side verification).
  Future<void> refreshUser() async {
    final res = await _api.get('/auth/me');
    user = AppUser.fromJson(res['user']);
    notifyListeners();
  }

  /// Invoked by [ApiClient] when an authenticated request returns 401. Signs the
  /// user out once and surfaces a "session expired" message. Guarded against
  /// re-entrancy when several in-flight requests all 401 at once.
  void _handleSessionExpired() {
    if (_handlingExpiry || status != AuthStatus.signedIn) return;
    _handlingExpiry = true;
    signOut().then((_) {
      sessionMessage = 'Your session expired. Please sign in again.';
      _handlingExpiry = false;
      notifyListeners();
    });
  }

  /// Read-and-clear the one-shot session message.
  String? takeSessionMessage() {
    final msg = sessionMessage;
    sessionMessage = null;
    return msg;
  }

  /// Permanently delete the account and all server-side data, then sign out.
  /// Required for Play Store compliance. Throws [ApiException] on failure so the
  /// UI can keep the user signed in and show the error.
  Future<void> deleteAccount() async {
    await _api.delete('/auth/me');
    await signOut();
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
  /// Returns true if the account is now subscribed.
  Future<bool> verifySubscription({
    required String purchaseToken,
    required String productId,
  }) async {
    final res = await _api.post('/billing/verify', {
      'purchaseToken': purchaseToken,
      'productId': productId,
    });
    user = AppUser.fromJson(res['user']);
    notifyListeners();
    return user?.isSubscribed ?? false;
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
