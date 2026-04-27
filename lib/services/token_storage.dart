import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Persists the long-lived refresh token in the platform secure store.
// Why not Hive: per V3 spec §3.1, the refresh token must never live in Hive
// because Hive is unencrypted on Android by default.
class TokenStorage {
  static const _refreshTokenKey = 'auth.refreshToken';

  final FlutterSecureStorage _storage;

  TokenStorage()
      : _storage = const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> readRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  Future<void> deleteRefreshToken() =>
      _storage.delete(key: _refreshTokenKey);
}
