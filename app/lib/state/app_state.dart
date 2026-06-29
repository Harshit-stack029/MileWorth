import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import '../models/insights.dart';
import '../models/summary.dart';
import '../models/trip.dart';
import '../models/user.dart';
import '../services/local_store.dart';

/// App lifecycle: [unknown] while bootstrapping, then [ready]. There is no
/// sign-in step — the app is local-only and always usable.
enum AppStatus { unknown, ready }

/// Single source of truth for trips, expenses and preferences. Backed entirely
/// by on-device storage ([LocalStore]); there is no account or network.
class AppState extends ChangeNotifier {
  AppState({LocalStore? store}) : _store = store ?? LocalStore();

  final LocalStore _store;

  AppStatus status = AppStatus.unknown;
  AppUser? user; // local preferences (rate / currency / weekend rule)
  List<Trip> trips = [];
  List<Expense> expenses = [];
  TripSummary summary = TripSummary.empty();
  bool loading = false;
  bool onboardingSeen = false;
  String? error;

  static const _onboardingKey = 'onboarding_seen';

  // Monotonic counter so trips/expenses created in the same microsecond still
  // get distinct ids.
  int _idCounter = 0;
  String _newId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  double get _rate => user?.mileageRate ?? LocalStore.defaultMileageRate;

  /// Called once at startup: load preferences + data from the device.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(_onboardingKey) ?? false;
    await _loadSettings();
    await _reload();
    status = AppStatus.ready;
    notifyListeners();
  }

  /// Mark first-run onboarding as completed so it never shows again.
  Future<void> completeOnboarding() async {
    onboardingSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final s = await _store.readSettings();
    user = AppUser(
      mileageRate: (s['mileageRate'] as num).toDouble(),
      currency: s['currency'] as String,
      classifyWeekendsAsPersonal: s['classifyWeekendsAsPersonal'] as bool,
    );
  }

  /// Per-trip deduction: business drives earn distance × rate; everything else
  /// is zero. Computed on read so a rate change reprices history instantly.
  Trip _tripFromMap(Map<String, dynamic> m) {
    final category = m['category'] as String? ?? 'uncategorized';
    final distance = (m['distance'] as num?)?.toDouble() ?? 0;
    final deduction = category == 'business' ? distance * _rate : 0.0;
    return Trip.fromJson({...m, 'deductionValue': deduction});
  }

  Future<void> _reload() async {
    final tripMaps = await _store.readTrips();
    trips = tripMaps.map(_tripFromMap).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    final expenseMaps = await _store.readExpenses();
    expenses = expenseMaps.map(Expense.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _recomputeSummary();
  }

  void _recomputeSummary() {
    double totalMiles = 0, totalDeductions = 0;
    int business = 0, uncategorized = 0;
    for (final t in trips) {
      totalMiles += t.distance;
      if (t.category == 'business') business++;
      if (t.category == 'uncategorized') uncategorized++;
      totalDeductions += t.deductionValue;
    }
    summary = TripSummary(
      totalMiles: totalMiles,
      totalTrips: trips.length,
      businessTrips: business,
      uncategorizedTrips: uncategorized,
      totalDeductions: totalDeductions,
    );
  }

  /// Reload everything from disk (wired to pull-to-refresh).
  Future<void> refresh() async {
    _setLoading(true);
    await _reload();
    _setLoading(false);
  }

  bool _isWeekend(DateTime dt) {
    final d = dt.toLocal().weekday;
    return d == DateTime.saturday || d == DateTime.sunday;
  }

  /// Create a trip. [payload] uses the same keys the GPS tracker / manual form
  /// already produce (startTime, endTime, distance, category, optional coords +
  /// routePolyline).
  Future<void> addTrip(Map<String, dynamic> payload) async {
    final maps = await _store.readTrips();
    var category = payload['category'] as String? ?? 'uncategorized';
    // Apply the "weekends are personal" rule to auto-detected (uncategorized)
    // drives only; a manually-chosen category is always respected.
    if (category == 'uncategorized' &&
        (user?.classifyWeekendsAsPersonal ?? false) &&
        _isWeekend(DateTime.parse(payload['startTime'] as String))) {
      category = 'personal';
    }
    maps.add({...payload, '_id': _newId(), 'category': category});
    await _store.writeTrips(maps);
    await refresh();
  }

  /// Reclassify a trip business <-> personal <-> uncategorized.
  Future<void> setCategory(Trip trip, String category) async {
    final maps = await _store.readTrips();
    for (final m in maps) {
      if (m['_id'] == trip.id) m['category'] = category;
    }
    await _store.writeTrips(maps);
    await refresh();
  }

  Future<void> deleteTrip(Trip trip) async {
    final maps = await _store.readTrips();
    maps.removeWhere((m) => m['_id'] == trip.id);
    await _store.writeTrips(maps);
    await refresh();
  }

  // --- Expenses ---

  Future<void> fetchExpenses() async {
    await _reload();
    notifyListeners();
  }

  Future<void> addExpense(Map<String, dynamic> payload) async {
    final maps = await _store.readExpenses();
    maps.add({...payload, '_id': _newId()});
    await _store.writeExpenses(maps);
    await _reload();
    notifyListeners();
  }

  Future<void> deleteExpense(Expense expense) async {
    final maps = await _store.readExpenses();
    maps.removeWhere((m) => m['_id'] == expense.id);
    await _store.writeExpenses(maps);
    await _reload();
    notifyListeners();
  }

  // --- Reports ---

  /// Totals for a date range, shown before exporting.
  Future<Map<String, dynamic>> reportSummary(DateTime from, DateTime to) async {
    final lo = DateTime(from.year, from.month, from.day);
    final hi = DateTime(to.year, to.month, to.day, 23, 59, 59);
    bool inRange(DateTime d) {
      final l = d.toLocal();
      return !l.isBefore(lo) && !l.isAfter(hi);
    }

    int totalTrips = 0, businessTrips = 0;
    double businessMiles = 0, totalDeductions = 0;
    for (final t in trips) {
      if (!inRange(t.startTime)) continue;
      totalTrips++;
      totalDeductions += t.deductionValue;
      if (t.category == 'business') {
        businessTrips++;
        businessMiles += t.distance;
      }
    }
    double totalExpenses = 0;
    for (final e in expenses) {
      if (!inRange(e.date)) continue;
      totalExpenses += e.amount;
    }
    return {
      'totalTrips': totalTrips,
      'businessTrips': businessTrips,
      'businessMiles': businessMiles,
      'totalExpenses': totalExpenses,
      'totalDeductions': totalDeductions,
    };
  }

  /// Build a CSV report for the date range and return its bytes (the reports
  /// screen writes them to a temp file and shares it). Local builds export CSV
  /// only — PDF generation needed a backend.
  Future<Uint8List> downloadReport({
    required String format,
    required DateTime from,
    required DateTime to,
  }) async {
    final lo = DateTime(from.year, from.month, from.day);
    final hi = DateTime(to.year, to.month, to.day, 23, 59, 59);
    bool inRange(DateTime d) {
      final l = d.toLocal();
      return !l.isBefore(lo) && !l.isAfter(hi);
    }

    String d(DateTime t) => t.toLocal().toIso8601String().substring(0, 10);
    final rows = <List<String>>[
      ['Type', 'Date', 'Category/Vendor', 'Distance (mi)', 'Amount/Deduction'],
    ];
    for (final t in trips.where((t) => inRange(t.startTime))) {
      rows.add([
        'Trip',
        d(t.startTime),
        t.category,
        t.distance.toStringAsFixed(2),
        t.deductionValue.toStringAsFixed(2),
      ]);
    }
    for (final e in expenses.where((e) => inRange(e.date))) {
      rows.add([
        'Expense',
        d(e.date),
        e.vendor ?? e.category ?? 'Expense',
        '',
        e.amount.toStringAsFixed(2),
      ]);
    }
    final csv = rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
    return Uint8List.fromList(utf8.encode(csv));
  }

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // --- Insights ---

  Future<Insights> fetchInsights() async {
    final counts = <String, int>{};
    final miles = <String, double>{};
    final values = <String, double>{};
    for (final t in trips) {
      counts[t.category] = (counts[t.category] ?? 0) + 1;
      miles[t.category] = (miles[t.category] ?? 0) + t.distance;
      values[t.category] = (values[t.category] ?? 0) + t.deductionValue;
    }
    final byCategory = counts.keys
        .map((c) => CategoryStat(
              category: c,
              count: counts[c]!,
              miles: miles[c]!,
              value: values[c]!,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    // Named-location ranking was a server feature; the screen handles an empty
    // list with a helpful hint.
    return Insights(byCategory: byCategory, topLocations: const []);
  }

  // --- Settings ---

  Future<void> updateSettings({
    double? mileageRate,
    String? currency,
    bool? classifyWeekendsAsPersonal,
  }) async {
    await _store.writeSettings(
      mileageRate: mileageRate,
      currency: currency,
      classifyWeekendsAsPersonal: classifyWeekendsAsPersonal,
    );
    await _loadSettings();
    await _reload(); // deduction totals depend on the rate
    notifyListeners();
  }

  void _setLoading(bool v) {
    loading = v;
    notifyListeners();
  }
}
