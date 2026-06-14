import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth-token persistence backed by the platform secure store
/// (iOS Keychain / Android Keystore-wrapped EncryptedSharedPreferences).
///
/// Earlier builds stored the token in plain SharedPreferences. We transparently
/// migrate that value into secure storage on first read, then delete the
/// plaintext copy, so upgrading users are not signed out.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _key = 'auth_token';
  static const _legacyKey = 'auth_token'; // old SharedPreferences key

  final FlutterSecureStorage _secure;

  Future<String?> read() async {
    final secureToken = await _secure.read(key: _key);
    if (secureToken != null) return secureToken;

    // One-time migration from the old plaintext SharedPreferences slot.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _key, value: legacy);
      await prefs.remove(_legacyKey);
      return legacy;
    }
    return null;
  }

  Future<void> write(String token) => _secure.write(key: _key, value: token);

  Future<void> clear() async {
    await _secure.delete(key: _key);
    // Belt-and-suspenders: also clear any lingering legacy copy.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKey);
  }
}
