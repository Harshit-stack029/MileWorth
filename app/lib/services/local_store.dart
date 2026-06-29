import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// On-device persistence for all app data.
///
/// MileWorth runs fully offline with no account and no backend: trips, expenses
/// and preferences all live in [SharedPreferences] as JSON. This is the single
/// storage layer behind [AppState].
class LocalStore {
  static const _tripsKey = 'trips_v1';
  static const _expensesKey = 'expenses_v1';
  static const _mileageRateKey = 'mileage_rate';
  static const _currencyKey = 'currency';
  static const _weekendsKey = 'weekends_personal';

  // Default US IRS standard mileage rate; the user can change it in Settings.
  static const double defaultMileageRate = 0.67;
  static const String defaultCurrency = 'USD';

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      // Corrupt blob — treat as empty rather than crashing startup.
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>> readTrips() => _readList(_tripsKey);
  Future<void> writeTrips(List<Map<String, dynamic>> trips) =>
      _writeList(_tripsKey, trips);

  Future<List<Map<String, dynamic>>> readExpenses() => _readList(_expensesKey);
  Future<void> writeExpenses(List<Map<String, dynamic>> expenses) =>
      _writeList(_expensesKey, expenses);

  Future<Map<String, dynamic>> readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'mileageRate': prefs.getDouble(_mileageRateKey) ?? defaultMileageRate,
      'currency': prefs.getString(_currencyKey) ?? defaultCurrency,
      'classifyWeekendsAsPersonal': prefs.getBool(_weekendsKey) ?? false,
    };
  }

  Future<void> writeSettings({
    double? mileageRate,
    String? currency,
    bool? classifyWeekendsAsPersonal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (mileageRate != null) await prefs.setDouble(_mileageRateKey, mileageRate);
    if (currency != null) await prefs.setString(_currencyKey, currency);
    if (classifyWeekendsAsPersonal != null) {
      await prefs.setBool(_weekendsKey, classifyWeekendsAsPersonal);
    }
  }
}
