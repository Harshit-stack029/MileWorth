import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight token persistence.
/// NOTE: Phase 1 only. Migrate to flutter_secure_storage before release —
/// SharedPreferences is not encrypted.
class TokenStorage {
  static const _key = 'auth_token';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
