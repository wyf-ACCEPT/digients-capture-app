import 'package:flutter/foundation.dart';

import '../models/auth.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

// Holds the current auth session and orchestrates sign-in / sign-out.
// The access token lives only on the in-memory AuthSession (rebuilt on every
// app launch via refresh); the refresh token is the only credential that ever
// touches disk, and only via TokenStorage (Keychain/Keystore).
class AuthController extends ChangeNotifier {
  final AuthService _service;
  final TokenStorage _tokens;

  AuthSession? _session;
  bool _isBusy = false;

  AuthController({required AuthService service, required TokenStorage tokens})
      : _service = service,
        _tokens = tokens;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isBusy => _isBusy;

  // Restore a session from a previously stored refresh token. Call on app start
  // before showing any routed UI so the router can decide auth vs. anon path.
  Future<void> bootstrap() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null) return;
    try {
      final res = await _service.refresh(refreshToken: refresh);
      await _adopt(res);
    } catch (e) {
      debugPrint('[AuthController] Refresh failed on bootstrap: $e');
      await _tokens.deleteRefreshToken();
    }
  }

  Future<void> startOtp({
    required String identifier,
    required AuthIdentifierType type,
  }) {
    return _withBusy(
      () => _service.startOtp(identifier: identifier, type: type),
    );
  }

  Future<void> verifyOtp({
    required String identifier,
    required String code,
  }) {
    return _withBusy(() async {
      final res =
          await _service.verifyOtp(identifier: identifier, code: code);
      await _adopt(res);
    });
  }

  Future<void> signInWithApple({
    required String identityToken,
    required String nonce,
  }) {
    return _withBusy(() async {
      final res = await _service.signInWithApple(
        identityToken: identityToken,
        nonce: nonce,
      );
      await _adopt(res);
    });
  }

  Future<void> signInWithGoogle({required String idToken}) {
    return _withBusy(() async {
      final res = await _service.signInWithGoogle(idToken: idToken);
      await _adopt(res);
    });
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    await _tokens.deleteRefreshToken();
    _session = null;
    notifyListeners();
    if (refresh != null) {
      try {
        await _service.logout(refreshToken: refresh);
      } catch (e) {
        // Server-side revoke is best-effort; local state is already cleared.
        debugPrint('[AuthController] Logout API call failed (ignored): $e');
      }
    }
  }

  Future<void> _adopt(AuthVerifyResponse res) async {
    await _tokens.saveRefreshToken(res.refreshToken);
    _session = AuthSession(accessToken: res.accessToken, profile: res.profile);
    notifyListeners();
  }

  Future<T> _withBusy<T>(Future<T> Function() body) async {
    _isBusy = true;
    notifyListeners();
    try {
      return await body();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
